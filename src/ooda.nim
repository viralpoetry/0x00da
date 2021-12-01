
import
  argparse, strutils, strformat, net, xmltree, httpclient, htmlparser

from streams import newFileStream
from templates import templateHTML, htmlFoot, htmlHeadBody, tr

var
  threads: array[0..4, Thread[seq[string]]] # array of 4 threads
  numThreads = len(threads) # number of threads
  chan: Channel[string]
  ctrlChan: Channel[int] # control channel

let
  csvHeaderRow = "respCode;fqdn;ipAddr;location;title"
  p = newParser("0x00DA"):
    flag("-H", "--html", help = "Produce HTML file")
    option("-o", "--output-file", help = "Output file for the ")
    option("-i", "--input-file", help = "Input file to be converted")
  opts = p.parse()

proc parseHtmlTitle(body: string): string =
  var ret = ""
  try:
    let html = parseHtml(body)
    let titleTag = html.findAll("title")[0]
    let stripped = titleTag.innerText().strip()
    ret = stripped.replace("\n", " ")
  except IndexDefect:
    ret = "n/a [could be second redirect]" # this happen when there is a second redirect
  except AssertionDefect:
    ret = "n/a"
  return ret

proc threadFunc(partialUrls: seq[string]) {.thread.} =
  for url in partialUrls:
    let client = newHttpClient(maxRedirects = 0, timeout = 300)
    var
      msg: string
      ipAddr: string
      location = "n/a"
    # try to connect and collect basic information
    try:
      let response = client.request(url, httpMethod = HttpGet)
      # get the IP address
      ipAddr = client.getSocket.getPeerAddr[0]
      # close the connection
      client.close()
      let title = parseHtmlTitle(response.body)
      # if there is a redirect, collect the location
      if response.status.startsWith("30"):
        location = response.headers.getOrDefault("location")
      msg = fmt"{response.status[.. 3]};{url};{ipAddr};{location};{title}"
    except SslError:
      continue
    except OSError:  # Connection timed out
      continue
    except ProtocolError:  # Connection was closed
      continue
    except TimeoutError:  # Timed out
      continue
    # sent the results to chan
    chan.send(msg)
  # exit thread
  ctrlChan.send(1)

when isMainModule:
  if opts.html:
    # Convert CSV file to a HTML table
    if opts.output_file == "" or opts.input_file == "":
      echo "Define input/output files to be converted."
    else:
      echo "Generating HTML table file..."
      templateHTML(opts.input_file, opts.output_file)
  else:
    # all urls loaded from stdin
    var urls: seq[string]
    # Parse stdin input line by line and try to observe where it leads to
    while not endOfFile(stdin):
      var url: string = readLine(stdin)
      # if no uri scheme is supplied, use https
      if not url.startsWith("http://") or url.startsWith("https://"):
        url = "https://" & url
        urls.add(url)
    # divide urls to be crawled by multiple threads
    var inputLen = len(urls)
    var fairShare = int (inputLen / numThreads)
    var firstShare = inputLen - ((numThreads - 1) * fairShare)
    # print the CSV header first
    echo csvHeaderRow
    # create channels for control and crawler
    ctrlChan.open()
    chan.open()
    # create the crawler threads and provide them urls
    # first thread
    var index = firstShare
    createThread(threads[0], threadFunc, urls[0..firstShare - 1])
    # the rest of threads
    for i in 1..high(threads):
      createThread(threads[i], threadFunc, urls[index..index + fairShare - 1])
      # calculate index for the next thread
      index = index + fairShare
    var finished = 0
    while true:
      # receive the actual result in a non-blocking way
      let crawlerMsg = chan.tryRecv()
      if crawlerMsg.dataAvailable:
        echo crawlerMsg.msg
      # receive control message once the thread ended
      # This must run after we receive the actual messages !
      let ctrlMsg = ctrlChan.tryRecv()
      if ctrlMsg.dataAvailable:
        finished = finished + 1
        if finished >= numThreads:
          # all threads finished
          break
      sleep(10)
    joinThreads(threads)
    chan.close()
    ctrlChan.close()
