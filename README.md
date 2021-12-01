# 0x00DA toolkit  

`ooda` will visit provided addresses and save HTTP code, Title, IP address or redirect.  

## Build  
```
nible build
```

## Usage  

Expected input is one FQDN per line.  

Visit addresses and save to a CSV file  
```
cat example.com.txt | ooda > example.com.csv
```

Generate HTML table from the CSV findings
```
ooda -H -i example.com.csv -o example.com.html
```

## TODO  
```
# lower socket timeout by using tcp.dial directly?
# use async instead of threads?
# use browser user-agent
# sort html results when converting
# diagnoze what kind of ssl error?
# what to do with "parseHtml(body) - IndexDefect" in title?
# sanitize title so we dont get h4cked ourselves
# add -h --help
```
