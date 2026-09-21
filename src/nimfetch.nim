import std/[json, os, sequtils, strutils, terminal]
import sysinfo

const Version = "0.1.0"

type Options = object
  logo, color, json: bool

type DisplayRow = object
  key, value: string
  isTitle, isSeparator, isPalette: bool

proc logoFor(name: string): seq[string] =
  case name
  of "arch": @[r"       /\", r"      /  \", r"     /\   \", r"    /      \",
                 r"   /   ,,   \", r"  /   |  |  -\", r" /_-''    ''-_\"]
  of "ubuntu": @["         _", "     ---(@)", r" _/  ---  \", "(@) |   |",
                   r"  \  --- _/", "     ---(@)"]
  of "debian": @["  _____", r" /  __ \", "|  /    |", r"|  \___-", "-_", "  --_"]
  of "fedora": @["      _____", r"     /   __)\", r"     |  /  \", "  ___|  |__/",
                  " / (_    _)", "/ /  |  |", r"\ \__/  |", r" \_____/"]
  else: @["    .--.", "   |o_o |", "   |:_/ |", r"  //   \ \", " (|     | )",
          r"/'\_   _/'\", r"\___)=(___/"]

proc help() =
  echo "nimfetch ", Version, " - fast system information in Nim"
  echo ""
  echo "Usage: nimfetch [options]"
  echo "  --no-logo       Hide the ASCII logo"
  echo "  --logo <name>   Use arch, ubuntu, debian, fedora, or linux"
  echo "  --no-color      Disable ANSI colors"
  echo "  --json          Print machine-readable JSON"
  echo "  -v, --version   Show version"
  echo "  -h, --help      Show this help"

proc parseOptions(): tuple[options: Options, logoName: string] =
  result.options = Options(logo: true, color: true)
  var i = 1
  while i <= paramCount():
    case paramStr(i)
    of "--no-logo": result.options.logo = false
    of "--no-color": result.options.color = false
    of "--json": result.options.json = true; result.options.logo = false
    of "--logo":
      inc i
      if i > paramCount():
        stderr.writeLine "nimfetch: --logo requires a name"
        quit 2
      result.logoName = paramStr(i).toLowerAscii
    of "-v", "--version": echo Version; quit 0
    of "-h", "--help": help(); quit 0
    else:
      stderr.writeLine "nimfetch: unknown option: " & paramStr(i)
      stderr.writeLine "Try 'nimfetch --help'."
      quit 2
    inc i

proc colored(text, code: string, enabled: bool): string =
  if enabled: "\e[" & code & "m" & text & "\e[0m" else: text

proc main() =
  var (options, logoName) = parseOptions()
  if not isatty(stdout): options.color = false
  let info = collectInfo()

  if options.json:
    var output = newJObject()
    for item in info:
      output[item.key.toLowerAscii.replace(" ", "_").replace("(/)", "root")] = %item.value
    echo pretty(output)
    return

  if logoName.len == 0: logoName = osRelease().id
  if logoName notin ["arch", "ubuntu", "debian", "fedora", "linux"]: logoName = "linux"
  let logo = if options.logo: logoFor(logoName) else: @[]
  var displayRows: seq[DisplayRow]
  for item in info:
    if item.key == "Title":
      displayRows.add DisplayRow(value: item.value, isTitle: true)
      displayRows.add DisplayRow(value: "-".repeat(item.value.len), isSeparator: true)
    else:
      displayRows.add DisplayRow(key: item.key, value: item.value)
  displayRows.add DisplayRow(value: "● ● ● ● ● ● ● ●", isPalette: true)

  let rows = max(logo.len, displayRows.len)
  let width = if logo.len > 0: logo.mapIt(it.len).max + 4 else: 0

  for i in 0 ..< rows:
    let left = if i < logo.len: colored(logo[i].alignLeft(width), "36;1", options.color)
               else: " ".repeat(width)
    if i < displayRows.len:
      let row = displayRows[i]
      if row.isTitle:
        echo left, colored(row.value, "32;1", options.color)
      elif row.isSeparator:
        echo left, colored(row.value, "32", options.color)
      elif row.isPalette:
        echo left, colored(row.value, "36;1", options.color)
      else:
        echo left, colored(row.key & ":", "34;1", options.color), " ", row.value
    else:
      echo left

when isMainModule:
  main()
