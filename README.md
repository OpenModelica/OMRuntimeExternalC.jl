# OMRuntimeExternalC.jl

A wrapper library for Modelica Standard Library (MSL) external C code

get the dlls from: https://build.openmodelica.org/omc/julia/x86_64-mingw32.zip

## Loaded dynamic libraries
Currently the following libraries are loaded
    - ModelicaStandardTables
    - OpenModelicaRuntimeC
    - SimulationRuntimeC
    - ModelicaIO
    - ModelicaExternalC

## Limitations
Not all functions of these libraries have interfaces yet.
If you wish to contribute by adding an interface, please see api.jl how other interfaces have been added.
