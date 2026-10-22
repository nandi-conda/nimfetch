import std/[json, os, sequtils, strutils, terminal]
import layout, sysinfo

const
  Version = "0.1.1"
  MinInfoWidth = 30  # narrower than this beside the logo and the logo is hidden
  MinValueWidth = 12 # narrower than this after the key and values move under it

type Options = object
  logo, color, json: bool

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
  # Garuda is Arch-based and should use the Arch mark by default.
  if logoName == "garuda": logoName = "arch"
  if logoName notin ["arch", "ubuntu", "debian", "fedora", "linux"]: logoName = "linux"
  var logo = if options.logo: logoFor(logoName) else: @[]
  var width = if logo.len > 0: logo.mapIt(it.len).max + 4 else: 0
  # Wrap only for an interactive terminal (or an explicit COLUMNS) so piped
  # output keeps whole lines.
  let columns = if isatty(stdout) or existsEnv("COLUMNS"): terminalWidth() else: 0
  # On narrow screens the logo would squeeze the info into a sliver; drop it.
  if columns > 0 and logo.len > 0 and columns - width < MinInfoWidth:
    logo = @[]
    width = 0
  let infoWidth = if columns > 0: max(columns - width, 1) else: 0

  var lines: seq[string]
  for item in info:
    if item.key == "Title":
      let title = wrapText(item.value, infoWidth)
      for part in title: lines.add colored(part, "32;1", options.color)
      let ruleLen = title.mapIt(it.displayLen).max
      lines.add colored("-".repeat(ruleLen), "32", options.color)
    else:
      let key = colored(item.key & ":", "34;1", options.color)
      let indent = item.key.len + 2
      if infoWidth == 0 or infoWidth - indent >= MinValueWidth:
        # Continuation lines align under the start of the value.
        let parts = wrapText(item.value, infoWidth - indent)
        lines.add key & " " & parts[0]
        for part in parts[1 .. ^1]: lines.add " ".repeat(indent) & part
      else:
        # Too narrow for the key and value side by side: value goes below.
        lines.add key
        for part in wrapText(item.value, infoWidth - 2): lines.add "  " & part
  lines.add colored("● ● ● ● ● ● ● ●", "36;1", options.color)

  for i in 0 ..< max(logo.len, lines.len):
    let left = if i < logo.len: colored(logo[i].alignLeft(width), "36;1", options.color)
               else: " ".repeat(width)
    if i < lines.len: echo left, lines[i] else: echo left

when isMainModule:
  main()
