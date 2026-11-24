# OMRuntimeExternalC.jl

Julia bindings to the external C functions of the Modelica Standard Library (MSL): the table functions
(`CombiTable1D`, `CombiTable2D`, `CombiTimeTable`), strings, MAT-file I/O, files and streams, random
numbers and the FFT, and the tool side of `ModelicaUtilities.h` (`ModelicaError` and the other callbacks).
[OMBackend.jl](https://github.com/OpenModelica/OMBackend.jl) uses it to simulate models whose external
functions are in the Standard Library; it also works on its own.

```julia
import OMRuntimeExternalC as ORC
ORC.ModelicaStrings_length("hello")                               # 5
table = [1.0 2.0; 3.0 4.0]
id = ORC.ModelicaStandardTables_CombiTable1D_init2("NoName", "NoName", table, 2, 2, [2], 1, 1, 2, 0)
ORC.ModelicaStandardTables_CombiTable1D_getValue(id, 1, 2.0)      # 3.0
```

## The library
Everything is in one shared library, `libModelicaExternalC`, compiled from the C sources of the MSL
(tag `v4.1.0`, `Modelica/Resources/C-Sources`) and the shim `src/C/ModelicaCallbacks.c`, which implements
`ModelicaUtilities.h` for Julia. It links only the C library of the platform.

When the package loads, it takes the library from, in this order:
1. the directory in the environment variable `OMRUNTIMEEXTERNALC_LIBRARY_DIR`,
2. `deps/usr/lib` (`deps/usr/bin` on Windows) of the package, a build of the checkout,
3. `ModelicaExternalC_jll`, which Pkg installs with the package (built by Yggdrasil for every platform
   it supports). Its preference `libModelicaExternalC_path` (Preferences.jl) points it to your own build.

`OMRuntimeExternalC.libraryPath()` is the path of the loaded library (`nothing` if there is none).
How to build the library yourself and how a release is made: see the
[README](https://github.com/OpenModelica/OMRuntimeExternalC.jl#build-it-yourself).

## Errors
C code reports an error with `ModelicaError` or `ModelicaFormatError`, which do not return. Here such an
error is a Julia `ErrorException` with the message of the C code, thrown from the `ccall` that was running;
the library works afterwards. The `safe_*` functions of the shim catch the error in C, and their Julia
function throws `<function> failed: <message>`.

## Tests
```julia
import Pkg; Pkg.test("OMRuntimeExternalC")
```
The tests need the library (above).

## License
The package is under the OSMC Public License (OSMC-PL) 1.8 or the GNU AGPL version 3, at the recipient's
choice ([LICENSE.md](https://github.com/OpenModelica/OMRuntimeExternalC.jl/blob/master/LICENSE.md)). The
C sources of the MSL compiled into the library keep their own licenses (BSD 3-Clause, zlib):
[THIRD_PARTY_LICENSES.md](https://github.com/OpenModelica/OMRuntimeExternalC.jl/blob/master/THIRD_PARTY_LICENSES.md).
