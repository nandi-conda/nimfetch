import std/[os, posix, strutils, termios, unicode]

proc terminalColumns*(): int =
  ## Width of the terminal on stdout: COLUMNS if set, else the tty size,
  ## else 0. std/terminal's terminalWidth needs ctermid, which Android's
  ## bionic lacks, so this asks the tty directly.
  try:
    result = parseInt(getEnv("COLUMNS"))
    if result > 0: return
  except ValueError: discard
  result = 0
  var size: IOctl_WinSize
  for fd in [STDOUT_FILENO.cint, STDERR_FILENO, STDIN_FILENO]:
    if isatty(fd) != 0 and ioctl(fd, TIOCGWINSZ, addr size) != -1 and size.ws_col > 0:
      return int(size.ws_col)

proc displayLen*(text: string): int =
  ## Visible width of `text`, skipping ANSI escape sequences.
  var i = 0
  while i < text.len:
    if text[i] == '\e' and i + 1 < text.len and text[i + 1] == '[':
      i += 2
      while i < text.len and text[i] notin {'@'..'~'}: inc i
      inc i
    else:
      inc result
      i += max(1, runeLenAt(text, i))

proc wrapText*(text: string, width: int): seq[string] =
  ## Word-wraps `text` into lines at most `width` runes wide. Words longer
  ## than `width` are split. A `width` below 1 disables wrapping.
  if width < 1 or text.runeLen <= width: return @[text]
  var line: seq[Rune]
  for word in text.split(Rune(0x20)):
    var rest = word.toRunes
    if line.len > 0 and line.len + 1 + rest.len <= width:
      line.add Rune(' ')
      line.add rest
      continue
    if line.len > 0:
      result.add $line
      line.setLen 0
    while rest.len > width:
      result.add $rest[0 ..< width]
      rest = rest[width .. ^1]
    line = rest
  if line.len > 0 or result.len == 0: result.add $line
