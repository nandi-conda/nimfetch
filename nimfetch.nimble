version       = "0.1.1"
author        = "nimfetch contributors"
description   = "A fast, dependency-free system information tool written in Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["nimfetch"]

requires "nim >= 2.0.0"

task test, "Run the test suite":
  exec "nim c -r --nimcache:/tmp/nimfetch-tests --path:src tests/test_nimfetch.nim"

task release, "Build an optimized binary":
  exec "nim c -d:release --opt:speed --nimcache:/tmp/nimfetch-release -o:bin/nimfetch src/nimfetch.nim"
