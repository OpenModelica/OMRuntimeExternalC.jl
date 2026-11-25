# OMRuntimeExternalC.jl

[![CI](https://github.com/OpenModelica/OMRuntimeExternalC.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/OpenModelica/OMRuntimeExternalC.jl/actions/workflows/CI.yml) [![Coverage](https://img.shields.io/endpoint?url=https://openmodelica.github.io/OMRuntimeExternalC.jl/coverage.json)](https://github.com/OpenModelica/OMRuntimeExternalC.jl/actions/workflows/CI.yml?query=branch%3Amaster) [![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://OpenModelica.github.io/OMRuntimeExternalC.jl/dev/) [![License: AGPL-3.0 or OSMC-PL](https://img.shields.io/badge/license-AGPL--3.0%20or%20OSMC--PL-lightgrey.svg)](LICENSE.md)

Julia bindings to the external C functions of the Modelica Standard Library (MSL): the table functions
(`CombiTable1D`, `CombiTable2D`, `CombiTimeTable`), strings, MAT-file I/O, files and streams, random
numbers and the FFT, and the tool side of `ModelicaUtilities.h` (`ModelicaError` and the other callbacks).
It is used by [OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl) to simulate models whose
external functions are in the Standard Library, and it works on its own.

```julia
import OMRuntimeExternalC as ORC
ORC.ModelicaStrings_length("hello")                               # 5
table = [1.0 2.0; 3.0 4.0]
id = ORC.ModelicaStandardTables_CombiTable1D_init2("NoName", "NoName", table, 2, 2, [2], 1, 1, 2, 0)
ORC.ModelicaStandardTables_CombiTable1D_getValue(id, 1, 2.0)      # 3.0
```

## The library

Everything is in one shared library, `libModelicaExternalC` (`.dylib`, `.so`, `.dll`). It is compiled from

- the C sources of the Modelica Standard Library, tag `v4.1.0`, directory `Modelica/Resources/C-Sources`
  (`ModelicaStandardTables`, `ModelicaIO`, `ModelicaMatIO`, `ModelicaInternal`, `ModelicaStrings`,
  `ModelicaRandom`, `ModelicaFFT`, with the zlib of that directory), and
- [`src/C/ModelicaCallbacks.c`](src/C/ModelicaCallbacks.c), which implements `ModelicaUtilities.h` for Julia
  (`ModelicaError`, `ModelicaFormatMessage`, `ModelicaAllocateString` and the others).

It links nothing but the C library of the platform: no OpenModelica runtime, no BLAS, no SUNDIALS, no
gettext. It exports the `Modelica*` functions and the shim's `modelica_*` and `safe_*` functions.

### Errors
C code reports an error with `ModelicaError` or `ModelicaFormatError`, which do not return. In this
library such an error is a Julia error (`ErrorException`, with the message of the C code): the process
goes on, and the library works afterwards.

- The package sets an error handler when it loads (`modelica_set_error_handler` of the shim). An error of
  any function of the library, and of compiled external C code of a model that calls `ModelicaError`, is
  thrown from the `ccall` that was running, as `Modelica runtime error: <message>`.
- The `safe_*` functions of the shim catch the error in C and return a status; the Julia function throws
  `<function> failed: <message>`. Nine file functions of `ModelicaIO` and `ModelicaInternal` go
  this way.
- Without a handler (the library loaded by another program), the message goes to stderr and the process
  ends (`abort`).

### Where the package finds it
The library comes from `ModelicaExternalC_jll`, which Pkg installs with the package. Yggdrasil builds it
([`M/ModelicaExternalC`](https://github.com/JuliaPackaging/Yggdrasil/tree/master/M/ModelicaExternalC),
with `deps/build_libraries.sh` of this repository) for every platform it supports. The package loads it
when it loads (never when it precompiles), with `RTLD_GLOBAL`, so compiled external C code of a model that
calls `ModelicaError` and the others finds them in the process.

To use another build (your own, or one for a platform the JLL has no build for), set the JLL's preference
(Preferences.jl), as for every JLL:

```julia
using Preferences, ModelicaExternalC_jll
set_preferences!(ModelicaExternalC_jll, "libModelicaExternalC_path" => "/path/to/libModelicaExternalC.so")
```

`OMRuntimeExternalC.libraryPath()` is the path of the loaded library (`nothing` if there is none, with a
warning when the package loads).

### Build it yourself
Needs a C compiler (`cc`; MinGW `gcc` in MSYS2 on Windows) and the MSL sources:

```bash
git clone --filter=blob:none --no-checkout https://github.com/modelica/ModelicaStandardLibrary.git msl
git -C msl checkout v4.1.0 -- Modelica/Resources/C-Sources
deps/build_libraries.sh msl/Modelica/Resources/C-Sources deps/usr/lib      # deps/usr/bin on Windows
deps/check_library.sh deps/usr/lib/libModelicaExternalC.*                  # dependencies and exports
```

`MACOS_ARCH=x86_64|arm64` cross-compiles on macOS. The build takes about 6 s. Then name the file with the
preference above.

### CI
`.github/workflows/CI.yml` builds the library on five platforms (Linux in a manylinux_2_28 container: glibc
2.28 or newer), checks it and tests the package against it through the preference, on every pull request
and push; it also tests the package against `ModelicaExternalC_jll` itself on Linux, macOS and Windows.

## Tests

```julia
import Pkg; Pkg.test("OMRuntimeExternalC")
```
They need the library (above). They include a new Julia process that loads the package and checks
that the library is the only one added to the process, and one that loads the package before `Glib_jll`
(on Windows an unrelated gettext DLL of the earlier bundle broke Glib, OpenModelica/OMBackend.jl#101).

## Limitations

Not every function of the library has a Julia interface. See `src/api.jl` for the ones that have, and for
how to add another.

A Modelica error leaves the C code where it was reported (the C code frees what it holds before it
reports, as `ModelicaError` does not return). An error reported on a thread that Julia did not start has
no Julia caller: it must not happen there.

## License

**This package** is under the OSMC Public License (OSMC-PL) 1.8 or the GNU Affero General Public License version 3 (AGPL v3), at the recipient's choice, like OMFrontend and
OMBackend: [LICENSE.md](LICENSE.md) holds both. This covers the Julia code (`src/`, `test/`), the C shim
`src/C/ModelicaCallbacks.c` and the build scripts in `deps/`.

**The C files from the Modelica Standard Library are the MSL's, and the MSL's license applies to them.**
`libModelicaExternalC` is built from the C sources of the Modelica Standard Library
(`Modelica/Resources/C-Sources`, tag `v4.1.0`: ModelicaStandardTables, ModelicaIO, ModelicaMatIO,
ModelicaInternal, ModelicaStrings, ModelicaRandom, ModelicaFFT, with the zlib and the matio and kiss_fft
code they contain). Those files are not part of this package and not under the OSMC-PL or the AGPL. They are not copied
into this repository: `deps/build_libraries.sh` and the CI take them from the Standard Library. They are
licensed by the Modelica Association and contributors under the
[3-clause BSD license](https://modelica.org/licenses/modelica-3-clause-bsd) (each file has the text in its
header), and the zlib sources under the zlib license. [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) lists
every compiled file with its copyright holders and license, and has the license texts. It ships with the
library (`share/licenses/ModelicaExternalC` in the JLL), so a redistributed binary carries the notices
that these licenses require.
