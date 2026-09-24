#!/usr/bin/env bash
# Build the Modelica external C libraries for macOS from the Modelica Standard
# Library C sources, plus the ModelicaCallbacks shim.
#
#   deps/build_msl_c_macos.sh <MSL C-Sources dir> <output dir>
#
# <MSL C-Sources dir> is Modelica/Resources/C-Sources of a ModelicaStandardLibrary
# checkout (CI uses tag v4.0.0). The output dir receives
#   libModelicaMatIO, libModelicaIO, libModelicaStandardTables,
#   libModelicaExternalC, libModelicaCallbacks (.dylib)
# for the host architecture. Set MACOS_ARCH=x86_64|arm64 to cross-compile.
#
# The grouping of sources and the defines follow MSL's BuildProjects/gcc/Makefile;
# zlib is the system one. The Modelica callbacks (ModelicaError,
# ModelicaAllocateString, ...) stay undefined in the MSL libraries and resolve at
# load time from libModelicaCallbacks, which OMRuntimeExternalC preloads with
# RTLD_GLOBAL before the others.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <MSL C-Sources dir> <output dir>" >&2
  exit 2
fi
SRC=$(cd "$1" && pwd)
OUT=$2
PKG=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$SRC/ModelicaStandardTables.c" ] || { echo "no MSL C sources in $SRC" >&2; exit 1; }

export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
ARCHFLAGS=()
[ -n "${MACOS_ARCH:-}" ] && ARCHFLAGS=(-arch "$MACOS_ARCH")

CFLAGS=(-O2 -fPIC -Wno-attributes -fno-delete-null-pointer-checks)
# _LITTLE_ENDIAN: MatIO's MAT v4 writer (Mat_VarWrite4 in ModelicaMatIO.c) only
# recognises glibc and x86 endianness macros and fails on arm64 macOS without it.
# Both macOS architectures are little-endian.
CPPFLAGS=(-DNDEBUG -DHAVE_UNISTD_H -DHAVE_STDARG_H -DHAVE_HIDDEN -DHAVE_MEMCPY
          -DHAVE_ZLIB=1 -D_LITTLE_ENDIAN)

# Build in a staging directory and move the results into place, so a running
# Julia process that has the old libraries mapped is not disturbed.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# lib <name> <sources...> -- <extra link arguments...>
lib() {
  local name=$1; shift
  local srcs=()
  while [ "$1" != "--" ]; do srcs+=("$1"); shift; done
  shift
  cc -dynamiclib ${ARCHFLAGS[@]+"${ARCHFLAGS[@]}"} "${CFLAGS[@]}" "${CPPFLAGS[@]}" -I"$SRC" \
     -o "$STAGE/lib$name.dylib" -install_name "@rpath/lib$name.dylib" \
     -Wl,-rpath,@loader_path -undefined dynamic_lookup "${srcs[@]}" "$@"
  echo "built lib$name.dylib"
}

lib ModelicaMatIO "$SRC/ModelicaMatIO.c" "$SRC/snprintf.c" -- -lz
lib ModelicaIO "$SRC/ModelicaIO.c" -- -L"$STAGE" -lModelicaMatIO
lib ModelicaStandardTables "$SRC/ModelicaStandardTables.c" "$SRC/ModelicaStandardTablesUsertab.c" \
    -- -L"$STAGE" -lModelicaIO -lModelicaMatIO
lib ModelicaExternalC "$SRC/ModelicaFFT.c" "$SRC/ModelicaInternal.c" \
    "$SRC/ModelicaRandom.c" "$SRC/ModelicaStrings.c" --
# Same shim deps/build.jl compiles when no prebuilt one is available.
cc -dynamiclib ${ARCHFLAGS[@]+"${ARCHFLAGS[@]}"} -fPIC -o "$STAGE/libModelicaCallbacks.dylib" \
   -install_name "@rpath/libModelicaCallbacks.dylib" "$PKG/src/modelica_callbacks.c" -ldl
echo "built libModelicaCallbacks.dylib"

mkdir -p "$OUT"
mv -f "$STAGE"/*.dylib "$OUT"/
ls -l "$OUT"
