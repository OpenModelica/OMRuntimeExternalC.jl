#= /*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-2026, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
 * THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 * RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
 * VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the OSMC (Open Source Modelica Consortium)
 * Public License (OSMC-PL) are obtained from OSMC, either from the above
 * address, from the URLs:
 * http://www.openmodelica.org or
 * https://github.com/OpenModelica/ or
 * http://www.ida.liu.se/projects/OpenModelica,
 * and in the OpenModelica distribution.
 *
 * GNU AGPL version 3 is obtained from:
 * https://www.gnu.org/licenses/licenses.html#GPL
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */ =#

#= The library libModelicaExternalC: where it is, and how the package finds it.

   The library is built from the C sources of the Modelica Standard Library and the shim
   src/C/ModelicaCallbacks.c (deps/build_libraries.sh). It is found in this order:
     1. the directory in the environment variable OMRUNTIMEEXTERNALC_LIBRARY_DIR,
     2. deps/usr/lib (deps/usr/bin on Windows), where a build of this checkout puts it,
     3. ModelicaExternalC_jll (built by Yggdrasil, M/ModelicaExternalC), which Pkg installs with the
        package. Its path can be overridden with the preference "libModelicaExternalC_path" of
        ModelicaExternalC_jll (Preferences.jl), as for every JLL.
   1 and 2 are kept for local builds and the setups that used them before the JLL. The JLL does not
   open the library itself (dont_dlopen): this package opens exactly one of the three, RTLD_GLOBAL.
   The place is looked up when the package loads (__init__), never when it precompiles: the cache
   of a precompile holds no path. =#

"""
    libraryFileName::String

The file name of the library on this platform.
"""
const libraryFileName::String =
  Sys.iswindows() ? "libModelicaExternalC.dll" : Sys.isapple() ? "libModelicaExternalC.dylib" : "libModelicaExternalC.so"

"""
    libModelicaExternalC::String

The name `ccall` uses for the library, as the JLL packages do: the library is loaded by its full
path in `__init__`, and the system finds the loaded one under this name (its install name on macOS,
its SONAME on Linux, its module name on Windows).
"""
const libModelicaExternalC::String = Sys.isapple() ? "@rpath/" * libraryFileName : libraryFileName

const LIBRARY_DIRECTORY_VARIABLE = "OMRUNTIMEEXTERNALC_LIBRARY_DIR"

#= The subdirectory of deps/usr that holds the library. =#
const LIBRARY_SUBDIRECTORY::String = Sys.iswindows() ? "bin" : "lib"

const libraryLocation = Ref{Union{Nothing, String}}(nothing)

"""
    jllDirectory()::Union{Nothing, String}

The directory of the library of ModelicaExternalC_jll (or of the file its preference
`libModelicaExternalC_path` names); `nothing` on a platform the JLL has no build for.
"""
function jllDirectory()::Union{Nothing, String}
  ModelicaExternalC_jll.is_available() || return nothing
  local path::String = ModelicaExternalC_jll.libModelicaExternalC_path
  return isfile(path) ? dirname(path) : nothing
end

"""
    libraryDirectory(environment = ENV)::Union{Nothing, String}

The directory with libModelicaExternalC, in the order of the list at the top of this file: the
directory of the environment variable `OMRUNTIMEEXTERNALC_LIBRARY_DIR`, the build directory
`deps/usr/lib` (`bin` on Windows), ModelicaExternalC_jll. `nothing` when none of them has the library
file.
"""
function libraryDirectory(environment::AbstractDict{String, String} = ENV)::Union{Nothing, String}
  local candidates::Vector{Union{Nothing, String}} = Union{Nothing, String}[
    get(environment, LIBRARY_DIRECTORY_VARIABLE, nothing),
    normpath(joinpath(@__DIR__, "..", "deps", "usr", LIBRARY_SUBDIRECTORY)),
  ]
  for dir::Union{Nothing, String} in candidates
    dir !== nothing && isfile(joinpath(dir, libraryFileName)) && return dir
  end
  local fromJll::Union{Nothing, String} = jllDirectory()
  return fromJll !== nothing && isfile(joinpath(fromJll, libraryFileName)) ? fromJll : nothing
end

"""
    libraryPath()::Union{Nothing, String}

The full path of the loaded libModelicaExternalC, `nothing` if the library was not found or did not
load. Its functions are the Modelica external C functions of the Standard Library (`dlsym` finds them
in it) and the `safe_*` functions of the shim.
"""
libraryPath()::Union{Nothing, String} = libraryLocation[]

"""
    loadLibrary()::Union{Nothing, String}

Load libModelicaExternalC with `RTLD_GLOBAL`, so that compiled external C code of a model, which
calls `ModelicaError` and the other functions of ModelicaUtilities.h, finds them in the process.
Returns the path, `nothing` (with a warning) if there is no library or it does not load.
"""
function loadLibrary()::Union{Nothing, String}
  local dir::Union{Nothing, String} = libraryDirectory()
  if dir === nothing
    @warn """OMRuntimeExternalC: $libraryFileName not found. Calls of external Modelica functions will fail.
      ModelicaExternalC_jll has no build for this platform. Build it with deps/build_libraries.sh into
      deps/usr/$LIBRARY_SUBDIRECTORY, or name its file with the preference libModelicaExternalC_path of
      ModelicaExternalC_jll, or its directory with $LIBRARY_DIRECTORY_VARIABLE."""
    return nothing
  end
  local path::String = joinpath(dir, libraryFileName)
  try
    Libdl.dlopen(path, Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
  catch err
    @warn "OMRuntimeExternalC: $libraryFileName did not load" path exception = err
    return nothing
  end
  return path
end
