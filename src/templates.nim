## HTML templates and the supporting functions.

import
  strutils, parsecsv, tables

let
  colors = {"200": "okColor", "300": "redirColor", "400": "notfoundColor"}.toTable
  htmlFoot* = """</tbody></table></div></body></html>"""
  tr* = """
    <tr>
        <td><span class="%%color">%%respCode</span></td>
        <td><a href="%%fqdn">%%fqdn</a></td>
        <td>%%title</td>
        <td><span class="location">%%location</span></td>
        <td>%%ipAddr</td>
    </tr>
    """
  htmlHeadBody* = """
      <!DOCTYPE html><html><head><title>0x00DA</title>
      <style>
          .okColor { background-color: rgba(60, 179, 113, .4); }
          .redirColor { background-color: rgba(255, 165, 0, .4); }
          .notfoundColor { background-color: rgba(255, 99, 71, .4); }
          .unknownRespCode { background-color: rgba(180, 180, 180, .4); }
      </style>
      </head>
      <script>
        /*!
         * tsorter 2.0.0 - Copyright 2015 Terrill Dent, http://terrill.ca
         * JavaScript HTML Table Sorter
         * Released under MIT license, http://terrill.ca/sorting/tsorter/LICENSE
         */
        var tsorter=function(){"use strict";var a,b,c,d=!!document.addEventListener;return Object.create||(Object.create=function(a){var b=function(){return void 0};return b.prototype=a,new b}),b=function(a,b,c){d?a.addEventListener(b,c,!1):a.attachEvent("on"+b,c)},c=function(a,b,c){d?a.removeEventListener(b,c,!1):a.detachEvent("on"+b,c)},a={getCell:function(a){var b=this;return b.trs[a].cells[b.column]},sort:function(a){var         b=this,c=a.target;b.column=c.cellIndex,b.get=b.getAccessor(c.getAttribute("data-tsorter")),b.prevCol===b.column?(c.className="ascend"!==c.className?"ascend":"descend",b.reverseTable()):(c.className="ascend",-1!==b.prevCol&&"exc_cell"!==b.ths[b.prevCol].className&&(b.ths[b.prevCol].className=""),b.quicksort(0,b.trs.length)),b.prevCol=b.column},getAccessor:function(a){var b=this,c=b.accessors;if(c&&c[a])return c[a];switch(a){case"link":return function(a){return         b.getCell(a).firstChild.firstChild.nodeValue};case"input":return function(a){return b.getCell(a).firstChild.value};case"numeric":return function(a){return parseFloat(b.getCell(a).firstChild.nodeValue,10)};default:return function(a){return b.getCell(a).firstChild.nodeValue}}},exchange:function(a,b){var         c,d=this,e=d.tbody,f=d.trs;a===b+1?e.insertBefore(f[a],f[b]):b===a+1?e.insertBefore(f[b],f[a]):(c=e.replaceChild(f[a],f[b]),f[a]?e.insertBefore(c,f[a]):e.appendChild(c))},reverseTable:function(){var a,b=this;for(a=1;a<b.trs.length;a++)b.tbody.insertBefore(b.trs[a],b.trs[0])},quicksort:function(a,b){var c,d,e,f=this;if(!(a+1>=b)){if(b-a===2)return void(f.get(b-1)>f.get(a)&&f.exchange(b-1,a));for(c=a+1,d=b-        1,f.get(a)>f.get(c)&&f.exchange(c,a),f.get(d)>f.get(a)&&f.exchange(a,d),f.get(a)>f.get(c)&&f.exchange(c,a),e=f.get(a);;){for(d--;e>f.get(d);)d--;for(c++;f.get(c)>e;)c++;if(c>=d)break;f.exchange(c,d)}f.exchange(a,d),b-d>d-a?(f.quicksort(a,d),f.quicksort(d+1,b)):(f.quicksort(d+1,b),f.quicksort(a,d))}},init:function(a,c,d){var e,f=this;for("string"==typeof         a&&(a=document.getElementById(a)),f.table=a,f.ths=a.getElementsByTagName("th"),f.tbody=a.tBodies[0],f.trs=f.tbody.getElementsByTagName("tr"),f.prevCol=c&&c>0?c:-1,f.accessors=d,f.boundSort=f.sort.bind(f),e=0;e<f.ths.length;e++)b(f.ths[e],"click",f.boundSort)},destroy:function(){var a,b=this;if(b.ths)for(a=0;a<b.ths.length;a++)c(b.ths[a],"click",b.boundSort)}},{create:function(b,c,d){var e=Object.create(a);return e.init(b,c,d),e}}}();
        function init() {
            // custom sorter functions
            var sorter = tsorter.create('results', 0, {
                "http-code": function(row){
                  return parseInt( this.getCell(row).childNodes[0].textContent);
                },
                "location": function(row){
                  console.log(this.getCell(row).childNodes[0].textContent);
                  return this.getCell(row).childNodes[0].textContent;
                }
            });
            // click for initial sort
            document.getElementsByTagName("th")[0].click();
        }
        window.onload = init;
      </script>
      <body>
      <div class="container">
      <table id="results">
      <thead>
        <tr>
          <th data-tsorter="http-code">code</th>
          <th>fqdn</th>
          <th>title</th>
          <th>location</th>
          <th>ip address</th>
        </tr>
     </thead>
     <tbody>
      """

proc convertCSVtoHTML *(inFile: string, outFile: string) =
  ## Generates an HTML file from the provided CSV file.
  echo "Generating HTML file '", outFile, "' from CSV file '", inFile, "'..."
  var col = ""
  var pcsv: CsvParser
  try:
    pcsv.open(inFile, separator = ';')
  except OSError, CsvError:
    echo "Error: Unable to open input file: ", inFile
    quit(1)
  let fw = open(outFile, fmWrite)
  # Write HTML header
  fw.write(htmlHeadBody)
  pcsv.readHeaderRow()
  try:
    while pcsv.readRow(columns = 5):
      var color: string
      if pcsv.rowEntry("respCode").startswith("2"): color = colors["200"]
      elif pcsv.rowEntry("respCode").startswith("3"): color = colors["300"]
      elif pcsv.rowEntry("respCode").startswith("4"): color = colors["400"]
      else: color = "unknownRespCode"
      col = tr.multiReplace(
        ("%%color", color),
        ("%%respCode", pcsv.rowEntry("respCode").strip()),
        ("%%fqdn", pcsv.rowEntry("fqdn").strip()),
        ("%%ipAddr", pcsv.rowEntry("ipAddr").strip()),
        ("%%location", pcsv.rowEntry("location").strip()),
        ("%%title", pcsv.rowEntry("title").strip())
      )
      fw.write(col)
  except CsvError as e:
    echo "Error: CSV parsing error: ", e.msg
  close(pcsv)
  fw.write(htmlFoot)
  close(fw)
