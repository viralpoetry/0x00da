import pkg/htmlparser

import
  argparse, strutils, strformat, net, xmltree, httpclient

from streams import newFileStream
from templates import convertCSVtoHTML, htmlFoot, htmlHeadBody, tr

var
  threads: array[0..4, Thread[seq[string]]] # array of 4 threads
  numThreads = len(threads) # number of threads
  chan: Channel[string]
  ctrlChan: Channel[int] # control channel

let
  csvHeaderRow = "respCode;fqdn;ipAddr;location;title"
  p = newParser("0x00DA"):
    command("html"):
      arg("csvfile", help = "CSV file to be converted to HTML")

proc parseHtmlTitle(rawHtml: string): string =
  ## Parses the HTML and extracts the title text
  var ret = ""
  try:
    let html = parseHtml(rawHtml)
    let titleTag = html.findAll("title")[0]
    let stripped = titleTag.innerText().strip()
    ret = stripped.replace("\n", " ")
  except IndexDefect:
    ret = "n/a [could be second redirect]" # this happen when there is a second redirect
  except AssertionDefect:
    ret = "n/a"
  return ret

proc collectWebsiteInformation(partialUrls: seq[string]) {.thread.} =
  ## Collects information about the provided URLs and sends results to chan.
  ## Collected information includes HTTP response code, IP address, redirect location, and HTML title.
  ## Handles SSL errors, timeouts, and protocol errors gracefully by skipping those URLs.
  for url in partialUrls:
    let client = newHttpClient(maxRedirects = 0, timeout = 300)
    var
      msg: string
      ipAddr: string
      location = "n/a"
    try:
      # FIXME ugly preflight request because of the unimplemented timeout in newHttpClient
      # See https://github.com/nim-lang/Nim/issues/14807
      let socket = newSocket()
      let ctx = newContext()
      wrapSocket(ctx, socket)
      # Strip https:// URI scheme for socket connection
      socket.connect(url[8 .. ^1], Port(443), timeout=1000)
      socket.close()
      let response = client.request(url, httpMethod = HttpGet)
      ipAddr = client.getSocket.getPeerAddr[0]
      # close the connection
      client.close()
      let title = parseHtmlTitle(response.body)
      if response.status.startsWith("30"):
        # Collect redirect location
        location = response.headers.getOrDefault("location")
      msg = fmt"{response.status[0 .. 3]};{url};{ipAddr};{location};{title}"
    except SslError, OSError, ProtocolError, TimeoutError:
      # Just continue on these errors:
      # SSL error, Connection timed out, Connection was closed, Timed out
      continue
    chan.send(msg)
  # exit thread
  ctrlChan.send(1)

when isMainModule:
  try:
    var opts = p.parse()
    if opts.html.isSome:
      # Convert CSV to HTML
      let inputFile = opts.html.get.csvfile
      let outputFile = inputFile & ".html"
      convertCSVtoHTML(inputFile, outputFile)
      quit(0)
  except UsageError as e:
    echo e.msg
    echo p.help
    quit(1)
  except ShortCircuit as e:
    if e.flag == "argparse_help":
      echo p.help
      quit(1)
  var urls: seq[string]
  # Parse stdin input line by line and try to observe where it leads to
  while not endOfFile(stdin):
    var url: string = readLine(stdin)
    # Skip empty lines
    if url.len == 0:
      continue
    # Add URI if missing
    if not url.startsWith("https://"):
      url = "https://" & url
    urls.add(url)
  # Divide urls to be crawled by multiple threads
  var inputLen = len(urls)
  var fairShare = int (inputLen / numThreads)
  var firstShare = inputLen - ((numThreads - 1) * fairShare)
  # Print the CSV header first
  echo csvHeaderRow
  # Create control and crawler channels
  ctrlChan.open()
  chan.open()
  # Create the crawler threads and provide them urls
  # First thread:
  var index = firstShare
  createThread(threads[0], collectWebsiteInformation, urls[0..firstShare - 1])
  # The rest of threads:
  for i in 1..high(threads):
    createThread(threads[i], collectWebsiteInformation, urls[index..index + fairShare - 1])
    index = index + fairShare
  var finished = 0
  while true:
    # Receive results in a non-blocking way
    let crawlerMsg = chan.tryRecv()
    if crawlerMsg.dataAvailable:
      echo crawlerMsg.msg
    # Receive control message once the thread ended
    # This must run after we receive the actual messages !
    let ctrlMsg = ctrlChan.tryRecv()
    if ctrlMsg.dataAvailable:
      finished = finished + 1
      if finished >= numThreads:
        # All threads finished
        break
    sleep(10)
  joinThreads(threads)
  chan.close()
  ctrlChan.close()
