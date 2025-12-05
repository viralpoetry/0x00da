# 0x00DA toolkit  

`ooda` will visit provided websitesa and create the CSV file with:  
  * HTTP status code
  * Page title
  * IP address
  * Title or information about the redirect

## Build  
```
nimble build
```

## Usage  

Expected input is one FQDN per line.  

Visit addresses and output to stdout.
```
cat example.com.txt | ooda > example.com.csv
```

Generate HTML table from the CSV findings. The command will produce a self contained `<filename>.html` HTML file.
```
ooda html example.com.csv
```

## TODO  
```
# use async instead of threads?
# use browser user-agent
# sort html results when converting
# sanitize title so we dont get h4cked ourselves
```
