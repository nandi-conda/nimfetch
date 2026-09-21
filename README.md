# nimfetch

A small, fastfetch-inspired system information tool written in Nim. It has no
runtime dependencies and uses the normal system utilities available on the host.

## Build

```sh
nimble build -d:release
./nimfetch
```

Or compile directly:

```sh
nim c -d:release -o:nimfetch src/nimfetch.nim
```

## Usage

```text
nimfetch [--no-logo] [--logo arch|ubuntu|debian|fedora|linux]
         [--no-color] [--json] [--version] [--help]
```

The implementation targets Linux first, with basic macOS and Windows fallbacks.
Missing optional commands such as `lspci`, `ip`, or a package manager are shown
as `Unknown` instead of causing the program to fail.

## Test

```sh
nimble test
```
