# OMRuntimeExternalC.jl

A wrapper library for Modelica Standard Library (MSL) external C code.

## Prebuilt Binaries

Download the prebuilt shared libraries for your platform:

| Platform | Download | Status |
|----------|----------|--------|
| Windows (x86_64) | [x86_64-mingw32.zip](https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/libs-v0.1.0/x86_64-mingw32.zip) | Supported |
| Linux (x86_64) | [x86_64-linux-gnu.zip](https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/libs-v0.1.0/x86_64-linux-gnu.zip) | Supported |
| macOS | N/A | Not supported |

Extract the contents to `lib/ext/shared/` within this package.

**Note:** macOS is currently not supported due to dylib path issues in the OpenModelica build system.

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

This package is part of OMJL: https://github.com/JKRT/OM.jl

The prebuilt binary libraries are built from OpenModelica source code and are redistributed under their respective licenses:

- **SimulationRuntimeC** and **OpenModelicaRuntimeC**: Licensed under the [OSMC Public License (OSMC-PL) v1.8](https://github.com/OpenModelica/OpenModelica/blob/master/OSMC-License.txt), an AGPL-compatible open source license maintained by the Open Source Modelica Consortium.

- **ModelicaExternalC**, **ModelicaIO**, and **ModelicaStandardTables**: Derived from the [Modelica Standard Library](https://github.com/modelica/ModelicaStandardLibrary), licensed under the [3-Clause BSD License](https://modelica.org/licenses/modelica-3-clause-bsd).

For full license texts, see:
- OSMC-PL v1.8: https://github.com/OpenModelica/OpenModelica/blob/master/OSMC-License.txt
- Modelica 3-Clause BSD: https://modelica.org/licenses/modelica-3-clause-bsd
