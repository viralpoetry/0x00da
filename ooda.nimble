# Package

version       = "1.0.0"
author        = "Peter Gasper"
description   = "Check FQDNs for HTTP code, Title, IP address and/or redirect."
license       = "MIT"
srcDir        = "src"
bin           = @["ooda"]


# Dependencies

requires "nim >= 1.4.2",
         "argparse",
         "htmlparser"
