#!/usr/bin/env bash
# Build libModelicaExternalC from the C sources of the Modelica Standard Library.
#
#   deps/build_libraries.sh <MSL C-Sources dir> <output dir>
#
# <MSL C-Sources dir> is Modelica/Resources/C-Sources of a ModelicaStandardLibrary
# checkout (the tag v4.1.0; the commit is MSL_COMMIT below). The output dir receives
#   libModelicaExternalC.{dylib,so,dll}
# for the host: macOS, Linux, or Windows (MSYS2/MinGW, run from bash).
# MACOS_ARCH=x86_64|arm64 cross-compiles on macOS; CC names the C compiler.
#
# One shared library holds everything: ModelicaStandardTables, ModelicaIO, ModelicaMatIO
# (with snprintf.c and the zlib of the MSL tree), ModelicaInternal, ModelicaStrings,
# ModelicaRandom, ModelicaFFT, and src/C/ModelicaCallbacks.c, which implements
# ModelicaUtilities.h (ModelicaError, ModelicaAllocateString, ...). It links no
# OpenModelica runtime, no BLAS, no SUNDIALS and no gettext: the libc of the platform
# is its only dependency, so the Windows DLL has nothing to clash with (the gettext
# runtime of Glib, OpenModelica/OMBackend.jl#101).
#
# The defines follow MSL's BuildProjects/gcc/Makefile, and OpenModelica's own build of these
# sources (DUMMY_FUNCTION_USERTAB; TABLE_SHARE is not set). Only the Modelica* API, the
# modelica_* and safe_* functions are exported: the zlib and matio functions inside stay
# local, so a Julia package with its own zlib or matio is not interposed.
set -euo pipefail

MSL_COMMIT=8ae3d35c24e519cb2996cab20f3b13daf2b0c50a   # modelica/ModelicaStandardLibrary v4.1.0

if [ $# -ne 2 ]; then
  echo "usage: $0 <MSL C-Sources dir> <output dir>" >&2
  exit 2
fi
SRC=$(cd "$1" && pwd)
OUT=$2
PKG=$(cd "$(dirname "$0")/.." && pwd)
SHIM="$PKG/src/C/ModelicaCallbacks.c"
[ -f "$SRC/ModelicaStandardTables.c" ] || { echo "no MSL C sources in $SRC" >&2; exit 1; }
[ -d "$SRC/zlib" ] || { echo "no zlib sources in $SRC/zlib" >&2; exit 1; }

CC=${CC:-cc}
NAME=libModelicaExternalC
CFLAGS=(-O2 -fPIC -Wno-attributes -fno-delete-null-pointer-checks)
CPPFLAGS=(-DNDEBUG -DHAVE_UNISTD_H -DHAVE_STDARG_H -DHAVE_HIDDEN -DHAVE_MEMCPY
          -DHAVE_ZLIB=1 -D_LITTLE_ENDIAN)
# The names the library exports (shell patterns of the linker's export lists).
EXPORTS=(Modelica\* modelica_\* safe_\*)

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

case "$(uname -s)" in
  Darwin)
    FILE=$NAME.dylib
    export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
    [ -n "${MACOS_ARCH:-}" ] && CFLAGS+=(-arch "$MACOS_ARCH")
    for p in "${EXPORTS[@]}"; do echo "_$p"; done > "$STAGE/exports"
    LINK=(-dynamiclib -install_name "@rpath/$FILE" -Wl,-exported_symbols_list,"$STAGE/exports")
    ;;
  Linux)
    FILE=$NAME.so
    { echo "{ global:"; for p in "${EXPORTS[@]}"; do echo "  $p;"; done; echo "local: *; };"; } > "$STAGE/exports"
    LINK=(-shared -Wl,-soname,"$FILE" -Wl,--version-script="$STAGE/exports" -Wl,-Bsymbolic
          -Wl,--no-undefined -Wl,-z,relro,-z,now)
    ;;
  MINGW*|MSYS*|CYGWIN*)
    FILE=$NAME.dll
    # No libgcc or winpthread DLL next to the library; every symbol is exported.
    LINK=(-shared -static-libgcc -Wl,--export-all-symbols -Wl,--no-undefined)
    ;;
  *)
    echo "unsupported platform $(uname -s)" >&2; exit 1 ;;
esac

# One object per source file.
SOURCES=(
  "$SRC/ModelicaStandardTables.c" "$SRC/ModelicaStandardTablesUsertab.c"
  "$SRC/ModelicaIO.c" "$SRC/ModelicaMatIO.c" "$SRC/snprintf.c"
  "$SRC/ModelicaInternal.c" "$SRC/ModelicaStrings.c" "$SRC/ModelicaRandom.c" "$SRC/ModelicaFFT.c"
  "$SHIM"
)
for f in adler32 compress crc32 deflate gzclose gzlib gzread gzwrite infback inffast inflate \
         inftrees trees uncompr zutil; do
  SOURCES+=("$SRC/zlib/$f.c")
done

OBJECTS=()
for s in "${SOURCES[@]}"; do
  o="$STAGE/$(basename "$s" .c).o"
  extra=()
  case "$(basename "$s")" in
    ModelicaStandardTablesUsertab.c) extra=(-DDUMMY_FUNCTION_USERTAB) ;;
  esac
  "$CC" "${CFLAGS[@]}" "${CPPFLAGS[@]}" ${extra[@]+"${extra[@]}"} -I"$SRC" -I"$SRC/zlib" -c -o "$o" "$s"
  OBJECTS+=("$o")
done

# Link into the staging directory, then move into place: a running Julia process that has an
# old library mapped is not disturbed (macOS kills a process whose mapped library is rewritten).
LIBS=(-lm)
[ "$(uname -s)" = Linux ] && LIBS+=(-lpthread)
"$CC" "${CFLAGS[@]}" "${LINK[@]}" -o "$STAGE/$FILE" "${OBJECTS[@]}" "${LIBS[@]}"
echo "built $FILE from MSL $MSL_COMMIT"

mkdir -p "$OUT"
mv -f "$STAGE/$FILE" "$OUT/$FILE"
ls -l "$OUT"
