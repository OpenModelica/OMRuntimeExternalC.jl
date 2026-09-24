# OMRuntimeExternalC.jl

A wrapper library for Modelica Standard Library (MSL) external C code.

## Prebuilt Binaries

Download the prebuilt shared libraries for your platform:

| Platform | Download | Status |
|----------|----------|--------|
| Windows (x86_64) | [x86_64-mingw32.zip](https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/libs-v0.1.0/x86_64-mingw32.zip) | Supported |
| Linux (x86_64) | [x86_64-linux-gnu.zip](https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/libs-v0.1.0/x86_64-linux-gnu.zip) | Supported |
| macOS (Apple silicon) | `aarch64-apple-darwin.zip` in the newest [`libs-*` release](https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases) | Supported once uploaded (see below) |
| macOS (Intel) | `x86_64-apple-darwin.zip` in the newest [`libs-*` release](https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases) | Supported once uploaded (see below) |

Extract the contents to `lib/ext/shared/` within this package. `Pkg.build("OMRuntimeExternalC")` does this for you.

### macOS

The OpenModelica build of these libraries does not work on macOS (dylib path
issues), so the macOS binaries are built from the Modelica Standard Library C
sources instead: `ModelicaExternalC`, `ModelicaStandardTables`, `ModelicaIO`,
`ModelicaMatIO` and the `ModelicaCallbacks` shim, which are all that `src/api.jl`
calls. The `OpenModelicaRuntimeC`, `SimulationRuntimeC` and `omcgc` libraries of
the other platforms are not included.

- CI: the `macOS libraries` workflow (`.github/workflows/macos-libs.yml`) builds
  both architectures and runs the tests on Julia 1.12 and 1.13. Run it by hand
  with `release_tag` set to the current `libs-*` release to upload the zips there.
- Locally, from a ModelicaStandardLibrary checkout (tag v4.0.0):

  ```bash
  deps/build_msl_c_macos.sh <ModelicaStandardLibrary>/Modelica/Resources/C-Sources lib/ext/shared/aarch64-apple-darwin
  ```

  Library paths are fixed when the package is precompiled, so put the libraries
  in place before loading it (or delete its compile cache afterwards).

## Loaded Dynamic Libraries

The following libraries are loaded at runtime:

- `ModelicaStandardTables` - Interpolation table functions
- `OpenModelicaRuntimeC` - OpenModelica runtime utilities
- `SimulationRuntimeC` - Simulation runtime functions
- `ModelicaIO` - I/O utilities
- `ModelicaExternalC` - External C interface functions

## Limitations

Not all functions of these libraries have interfaces yet.
If you wish to contribute by adding an interface, please see `api.jl` for examples of how other interfaces have been added.

## License

This package is part of OMJL: https://github.com/OpenModelica/OM.jl

The prebuilt binary libraries are built from OpenModelica source code and are redistributed under their respective licenses:

- **SimulationRuntimeC** and **OpenModelicaRuntimeC**: Licensed under the [OSMC Public License (OSMC-PL) v1.8](https://github.com/OpenModelica/OpenModelica/blob/master/OSMC-License.txt), an AGPL-compatible open source license maintained by the Open Source Modelica Consortium.

- **ModelicaExternalC**, **ModelicaIO**, and **ModelicaStandardTables**: Derived from the [Modelica Standard Library](https://github.com/modelica/ModelicaStandardLibrary), licensed under the [3-Clause BSD License](https://modelica.org/licenses/modelica-3-clause-bsd).

For full license texts, see:
- OSMC-PL v1.8: https://github.com/OpenModelica/OpenModelica/blob/master/OSMC-License.txt
- Modelica 3-Clause BSD: https://modelica.org/licenses/modelica-3-clause-bsd
