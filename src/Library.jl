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

   The library comes from ModelicaExternalC_jll, which Pkg installs with the package. Yggdrasil
   (M/ModelicaExternalC) builds it from the C sources of the Modelica Standard Library and the shim
   src/C/ModelicaCallbacks.c with deps/build_libraries.sh. Another build (a local one, or one for a
   platform the JLL has no build for) is used through the preference "libModelicaExternalC_path" of
   ModelicaExternalC_jll (Preferences.jl), as for every JLL. The JLL does not open the library
   itself (dont_dlopen): this package opens it, RTLD_GLOBAL.
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

const libraryLocation = Ref{Union{Nothing, String}}(nothing)

"""
    hasLibraryFile()::Bool

Whether there is a library file to load: ModelicaExternalC_jll has a build for this platform, or
its preference `libModelicaExternalC_path` names an existing file.
"""
function hasLibraryFile()::Bool
  return ModelicaExternalC_jll.is_available() && isfile(ModelicaExternalC_jll.libModelicaExternalC_path)
end

"""
    libraryFile()::String

The file of libModelicaExternalC: ModelicaExternalC_jll's, or the one its preference
`libModelicaExternalC_path` names (any file name). Meaningful when `hasLibraryFile()` holds.
"""
libraryFile()::String = ModelicaExternalC_jll.libModelicaExternalC_path

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
  if !hasLibraryFile()
    @warn """OMRuntimeExternalC: $libraryFileName not found. Calls of external Modelica functions will fail.
      ModelicaExternalC_jll has no build for this platform, or its preference libModelicaExternalC_path names
      no file. Build the library with deps/build_libraries.sh and name the file with that preference."""
    return nothing
  end
  local path::String = libraryFile()
  try
    Libdl.dlopen(path, Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
  catch err
    @warn "OMRuntimeExternalC: $libraryFileName did not load" path exception = err
    return nothing
  end
  return path
end
