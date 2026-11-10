# OMRuntimeExternalC.jl

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
  and has the `safe_*` functions that turn a Modelica error into a Julia error (`error(...)`, with the
  message of the C code) instead of ending the process.

It links nothing but the C library of the platform: no OpenModelica runtime, no BLAS, no SUNDIALS, no
gettext. It exports the `Modelica*` functions and the shim's `modelica_*` and `safe_*` functions.

### Where the package finds it
When the package loads (never when it precompiles), in this order:

1. the directory in the environment variable `OMRUNTIMEEXTERNALC_LIBRARY_DIR`,
2. `deps/usr/lib` (`deps/usr/bin` on Windows) of the package: a build of this checkout (below),
3. the artifact `ModelicaExternalC` of [`Artifacts.toml`](Artifacts.toml), which Pkg installs with the
   package (tarballs of the platforms `aarch64-apple-darwin`, `x86_64-apple-darwin`, `x86_64-linux-gnu`,
   `aarch64-linux-gnu`, `x86_64-w64-mingw32`, built by the CI and attached to a `libs-v*` release).

`OMRuntimeExternalC.libraryPath()` is the path of the loaded library (`nothing` if there is none, with a
warning when the package loads). The library is loaded with `RTLD_GLOBAL`, so compiled external C code of
a model that calls `ModelicaError` and the others finds them in the process.

### Build it yourself
Needs a C compiler (`cc`; MinGW `gcc` in MSYS2 on Windows) and the MSL sources:

```bash
git clone --filter=blob:none --no-checkout https://github.com/modelica/ModelicaStandardLibrary.git msl
git -C msl checkout v4.1.0 -- Modelica/Resources/C-Sources
deps/build_libraries.sh msl/Modelica/Resources/C-Sources deps/usr/lib      # deps/usr/bin on Windows
deps/check_library.sh deps/usr/lib/libModelicaExternalC.*                  # dependencies and exports
```

`MACOS_ARCH=x86_64|arm64` cross-compiles on macOS. The build takes about 6 s.

### Release
`.github/workflows/CI.yml` builds and tests on the five platforms. Run by hand with `release_tag` set
(`libs-v1.0.0`) it creates that release with the tarballs and hands back the `Artifacts.toml` for them
(`deps/bind_artifacts.jl`), which is committed. `deps/Yggdrasil/build_tarballs.jl` is the draft of a
recipe for a `ModelicaExternalC_jll`, as the alternative to the artifact.

## Tests

```julia
import Pkg; Pkg.test("OMRuntimeExternalC")
```
They need the library (above). They include a new Julia process that loads the package and checks
that the library is the only one added to the process, and one that loads the package before `Glib_jll`
(on Windows an unrelated gettext DLL of the earlier bundle broke Glib, OpenModelica/OMBackend.jl#101).

## Limitations

Not every function of the library has a Julia interface. See `src/api.jl` for the ones that have, and for
how to add another. A Modelica error in a function that is called directly (without a `safe_*` entry in the
shim) ends the process.

## License

This package: the [OSMC Public License](LICENSE.md) 1.8 or the AGPL version 3, at your choice.
The library contains C sources of the Modelica Standard Library under their own licenses, mostly the
3-clause BSD license, and zlib: see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md), which ships with the library
(`share/licenses/ModelicaExternalC`).
