#!/usr/bin/env bash
# Check a built libModelicaExternalC: it depends on nothing but the system libraries of its
# platform, and exports only the Modelica API (Modelica*, modelica_*, safe_*).
#
#   deps/check_library.sh <library file>
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <library file>" >&2; exit 2; }
LIB=$1
[ -f "$LIB" ] || { echo "no such file: $LIB" >&2; exit 2; }
fail=0

case "$(uname -s)" in
  Darwin)
    deps=$(otool -L "$LIB" | tail -n +2 | awk '{print $1}')
    unexpected=$(echo "$deps" | grep -v -E "^(@rpath/$(basename "$LIB")|/usr/lib/libSystem\.B\.dylib)$" || true)
    exports=$(nm -gU "$LIB" | awk '{print $3}' | sed 's/^_//')
    ;;
  Linux)
    deps=$(readelf -d "$LIB" | awk '/NEEDED/ {gsub(/[\[\]]/, "", $5); print $5}')
    unexpected=$(echo "$deps" | grep -v -E '^(libm\.so\.6|libc\.so\.6|libpthread\.so\.0|libdl\.so\.2|ld-linux-[a-z0-9_-]+\.so\.[0-9]+|ld-linux\.so\.[0-9]+)$' || true)
    exports=$(nm -D --defined-only "$LIB" | awk '{print $3}')
    ;;
  MINGW*|MSYS*|CYGWIN*)
    deps=$(objdump -p "$LIB" | awk '/DLL Name:/ {print tolower($3)}')
    unexpected=$(echo "$deps" | grep -v -E '^(kernel32\.dll|msvcrt\.dll|api-ms-win-crt-[a-z0-9-]+\.dll|ucrtbase\.dll)$' || true)
    exports=""
    ;;
  *) echo "unsupported platform" >&2; exit 2 ;;
esac

echo "libraries it depends on:"; echo "$deps" | sed 's/^/  /'
if [ -n "$unexpected" ]; then
  echo "UNEXPECTED dependencies:"; echo "$unexpected" | sed 's/^/  /'; fail=1
fi

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;  # every symbol is exported on Windows (the zlib and matio ones too)
  *)
    total=$(echo "$exports" | grep -c . || true)
    echo "exported symbols: $total"
    stray=$(echo "$exports" | grep -v -E '^(Modelica|modelica_|safe_)' || true)
    if [ -n "$stray" ]; then
      echo "UNEXPECTED exports:"; echo "$stray" | sed 's/^/  /'; fail=1
    fi
    [ "$total" -ge 50 ] || { echo "too few exports ($total)"; fail=1; }
    ;;
esac
[ "$fail" -eq 0 ] && echo "OK"
exit $fail
