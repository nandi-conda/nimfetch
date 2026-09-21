import std/[os, osproc, strformat, strutils]

type
  InfoItem* = object
    key*, value*: string

proc readFirst(path: string): string =
  try:
    readFile(path).strip
  except CatchableError:
    ""

proc command(cmd: string): string =
  try:
    let execution = execCmdEx(cmd, options = {poUsePath, poStdErrToStdOut})
    if execution.exitCode == 0: execution.output.strip else: ""
  except CatchableError:
    ""

proc osRelease*(): tuple[name, id: string] =
  result = (hostOS.capitalizeAscii, hostOS)
  when defined(linux):
    for line in readFirst("/etc/os-release").splitLines:
      let pos = line.find('=')
      if pos < 1: continue
      let key = line[0 ..< pos]
      let value = line[pos + 1 .. ^1].strip(chars = {'"', '\''})
      case key
      of "PRETTY_NAME": result.name = value
      of "ID": result.id = value.toLowerAscii
      else: discard

proc formatBytes*(bytes: int64): string =
  const units = ["B", "KiB", "MiB", "GiB", "TiB"]
  var value = bytes.float
  var unit = 0
  while value >= 1024 and unit < units.high:
    value /= 1024
    inc unit
  if unit == 0: &"{value.int} {units[unit]}" else: &"{value:.2f} {units[unit]}"

proc formatDuration*(seconds: int64): string =
  let days = seconds div 86400
  let hours = (seconds mod 86400) div 3600
  let minutes = (seconds mod 3600) div 60
  var parts: seq[string]
  if days > 0: parts.add &"{days}d"
  if hours > 0: parts.add &"{hours}h"
  parts.add &"{minutes}m"
  parts.join(" ")

proc kernel(): string =
  when defined(windows):
    result = command("ver")
  else:
    result = command("uname -sr")

proc uptime(): string =
  when defined(linux):
    let raw = readFirst("/proc/uptime").splitWhitespace
    if raw.len > 0:
      try: return formatDuration(int64(parseFloat(raw[0])))
      except ValueError: discard
  elif defined(macosx):
    import std/[parseutils, times]
    let boot = command("sysctl -n kern.boottime")
    let marker = "sec = "
    let start = boot.find(marker)
    if start >= 0:
      var epoch: int
      discard parseInt(boot, epoch, start + marker.len)
      return formatDuration(getTime().toUnix - epoch)
  "Unknown"

proc cpu(): string =
  when defined(linux):
    for line in readFirst("/proc/cpuinfo").splitLines:
      if line.startsWith("model name") or line.startsWith("Hardware"):
        let pos = line.find(':')
        if pos >= 0: return line[pos + 1 .. ^1].strip
  elif defined(macosx):
    result = command("sysctl -n machdep.cpu.brand_string")
  elif defined(windows):
    result = getEnv("PROCESSOR_IDENTIFIER")
  if result.len == 0: result = "Unknown"

proc gpu(): string =
  when defined(linux):
    result = command("lspci 2>/dev/null | sed -n '/VGA\\|3D controller/{s/.*: //;p;q;}'")
  elif defined(macosx):
    result = command("system_profiler SPDisplaysDataType | awk -F': ' '/Chipset Model/{print $2; exit}'")
  if result.len == 0: result = "Unknown"

proc memory(): string =
  when defined(linux):
    var total, available: int64
    for line in readFirst("/proc/meminfo").splitLines:
      let fields = line.splitWhitespace
      if fields.len < 2: continue
      try:
        if fields[0] == "MemTotal:": total = parseInt(fields[1]).int64 * 1024
        elif fields[0] == "MemAvailable:": available = parseInt(fields[1]).int64 * 1024
      except ValueError: discard
    if total > 0: return &"{formatBytes(total - available)} / {formatBytes(total)}"
  elif defined(macosx):
    let total = command("sysctl -n hw.memsize")
    if total.len > 0: return formatBytes(parseBiggestInt(total))
  "Unknown"

proc disk(): string =
  when defined(posix):
    let line = command("df -Pk / | tail -1").splitWhitespace
    if line.len >= 5:
      try:
        let total = parseBiggestInt(line[1]) * 1024
        let used = parseBiggestInt(line[2]) * 1024
        return &"{formatBytes(used)} / {formatBytes(total)} ({line[4]})"
      except ValueError: discard
  "Unknown"

proc packageCount(): string =
  var counts: seq[string]
  when defined(linux):
    let managers = [
      ("dpkg", "dpkg-query -f '${binary:Package}\\n' -W 2>/dev/null | wc -l"),
      ("rpm", "rpm -qa 2>/dev/null | wc -l"),
      ("pacman", "pacman -Qq 2>/dev/null | wc -l"),
      ("apk", "apk info 2>/dev/null | wc -l"),
      ("flatpak", "flatpak list --app --columns=application 2>/dev/null | wc -l")]
    for (manager, cmd) in managers.items:
      if findExe(manager).len > 0:
        let count = command(cmd)
        if count.len > 0 and count != "0": counts.add &"{count} ({manager})"
  if counts.len == 0: "Unknown" else: counts.join(", ")

proc desktop(): string =
  result = getEnv("XDG_CURRENT_DESKTOP")
  if result.len == 0: result = getEnv("DESKTOP_SESSION")
  if result.len == 0: result = "TTY"

proc localIp(): string =
  when defined(linux):
    let route = command("ip route get 1.1.1.1 2>/dev/null")
    let words = route.splitWhitespace
    let pos = words.find("src")
    if pos >= 0 and pos + 1 < words.len: return words[pos + 1]
    let addresses = command("hostname -I 2>/dev/null").splitWhitespace
    if addresses.len > 0: return addresses[0]
  result = "Unknown"

proc collectInfo*(): seq[InfoItem] =
  let distro = osRelease()
  let user = getEnv("USER", getEnv("USERNAME", "user"))
  let host = getEnv("HOSTNAME", command("hostname"))
  let shellPath = getEnv("SHELL", getEnv("COMSPEC", "Unknown"))
  let terminal = getEnv("TERM_PROGRAM", getEnv("TERM", "Unknown"))
  result = @[
    InfoItem(key: "Title", value: user & "@" & host),
    InfoItem(key: "OS", value: distro.name),
    InfoItem(key: "Host", value: host),
    InfoItem(key: "Kernel", value: kernel()),
    InfoItem(key: "Uptime", value: uptime()),
    InfoItem(key: "Packages", value: packageCount()),
    InfoItem(key: "Shell", value: extractFilename(shellPath)),
    InfoItem(key: "Display", value: getEnv("WAYLAND_DISPLAY", getEnv("DISPLAY", "TTY"))),
    InfoItem(key: "DE/WM", value: desktop()),
    InfoItem(key: "Terminal", value: terminal),
    InfoItem(key: "CPU", value: cpu()),
    InfoItem(key: "GPU", value: gpu()),
    InfoItem(key: "Memory", value: memory()),
    InfoItem(key: "Disk (/)" , value: disk()),
    InfoItem(key: "Local IP", value: localIp()),
    InfoItem(key: "Locale", value: getEnv("LANG", "Unknown"))]
