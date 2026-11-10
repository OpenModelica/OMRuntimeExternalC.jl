#!/usr/bin/env bash
# Pack libModelicaExternalC and its license files as the artifact tarball of one platform.
#
#   deps/package_library.sh <directory with the library> <platform triplet> <output directory>
#
# <platform triplet> is a Julia platform name: aarch64-apple-darwin, x86_64-apple-darwin,
# x86_64-linux-gnu, aarch64-linux-gnu or x86_64-w64-mingw32. The output is
# ModelicaExternalC.<triplet>.tar.gz with lib/<library> (bin/ on Windows) and
# share/licenses/ModelicaExternalC/{LICENSE.md,THIRD_PARTY_LICENSES.md}: the layout of the artifact
# "ModelicaExternalC" in Artifacts.toml (deps/bind_artifacts.jl).
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $0 <directory with the library> <platform triplet> <output directory>" >&2
  exit 2
fi
LIBDIR=$(cd "$1" && pwd)
TRIPLET=$2
OUT=$3
PKG=$(cd "$(dirname "$0")/.." && pwd)

case "$TRIPLET" in
  *-apple-darwin) FILE=libModelicaExternalC.dylib; SUB=lib ;;
  *-linux-gnu)    FILE=libModelicaExternalC.so;    SUB=lib ;;
  *-w64-mingw32)  FILE=libModelicaExternalC.dll;   SUB=bin ;;
  *) echo "unsupported platform $TRIPLET" >&2; exit 1 ;;
esac
[ -f "$LIBDIR/$FILE" ] || { echo "no $FILE in $LIBDIR" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/$SUB" "$STAGE/share/licenses/ModelicaExternalC"
cp "$LIBDIR/$FILE" "$STAGE/$SUB/$FILE"
cp "$PKG/LICENSE.md" "$PKG/THIRD_PARTY_LICENSES.md" "$STAGE/share/licenses/ModelicaExternalC/"

mkdir -p "$OUT"
TARBALL="$(cd "$OUT" && pwd)/ModelicaExternalC.$TRIPLET.tar.gz"
tar -czf "$TARBALL" -C "$STAGE" .
echo "$TARBALL"
