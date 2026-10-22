import std/[unittest]
import layout, sysinfo

suite "nimfetch helpers":
  test "formats byte quantities":
    check formatBytes(0) == "0 B"
    check formatBytes(1024) == "1.00 KiB"
    check formatBytes(1_073_741_824) == "1.00 GiB"

  test "formats durations":
    check formatDuration(60) == "1m"
    check formatDuration(3660) == "1h 1m"
    check formatDuration(90060) == "1d 1h 1m"

  test "collects core fields":
    let info = collectInfo()
    check info.len >= 10
    check info[0].key == "Title"
    check info[1].key == "OS"

  test "wraps long values at word boundaries":
    check wrapText("short", 20) == @["short"]
    check wrapText("Intel Core i7-8550U @ 1.80GHz", 12) ==
      @["Intel Core", "i7-8550U @", "1.80GHz"]
    check wrapText("abcdefghij", 4) == @["abcd", "efgh", "ij"]
    check wrapText("no limit here", 0) == @["no limit here"]

  test "measures visible width":
    check displayLen("\e[34;1mOS:\e[0m") == 3
    check displayLen("● ●") == 3
