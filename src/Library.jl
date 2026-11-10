#= The library libModelicaExternalC: where it is, and how the package finds it.

   The library is built from the C sources of the Modelica Standard Library and the shim
   src/C/ModelicaCallbacks.c (deps/build_libraries.sh). It is found in this order:
     1. the directory in the environment variable OMRUNTIMEEXTERNALC_LIBRARY_DIR,
     2. deps/usr/lib (deps/usr/bin on Windows), where a build of this checkout puts it,
     3. the artifact "ModelicaExternalC" of Artifacts.toml, which Pkg installs with the package.
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
const ARTIFACT_NAME = "ModelicaExternalC"

#= The subdirectory of the artifact and of deps/usr that holds the library. =#
const LIBRARY_SUBDIRECTORY::String = Sys.iswindows() ? "bin" : "lib"

const libraryLocation = Ref{Union{Nothing, String}}(nothing)

"""
    artifactDirectory()::Union{Nothing, String}

The directory of the library in the installed artifact "ModelicaExternalC", if Artifacts.toml has
an entry for this platform and the artifact is installed.
"""
function artifactDirectory()::Union{Nothing, String}
  local toml::Union{Nothing, String} = Artifacts.find_artifacts_toml(@__DIR__)
  toml === nothing && return nothing
  local meta::Union{Nothing, Dict{String, Any}} = Artifacts.artifact_meta(ARTIFACT_NAME, toml)
  meta === nothing && return nothing
  local path::String = Artifacts.artifact_path(Base.SHA1(meta["git-tree-sha1"]::String))
  return isdir(path) ? joinpath(path, LIBRARY_SUBDIRECTORY) : nothing
end

"""
    libraryDirectory(environment = ENV)::Union{Nothing, String}

The directory with libModelicaExternalC, in the order of the list at the top of this file: the
directory of the environment variable `OMRUNTIMEEXTERNALC_LIBRARY_DIR`, the build directory
`deps/usr/lib` (`bin` on Windows), the artifact. `nothing` when none of them has the library file.
"""
function libraryDirectory(environment::AbstractDict{String, String} = ENV)::Union{Nothing, String}
  local candidates::Vector{Union{Nothing, String}} = Union{Nothing, String}[
    get(environment, LIBRARY_DIRECTORY_VARIABLE, nothing),
    normpath(joinpath(@__DIR__, "..", "deps", "usr", LIBRARY_SUBDIRECTORY)),
  ]
  for dir::Union{Nothing, String} in candidates
    dir !== nothing && isfile(joinpath(dir, libraryFileName)) && return dir
  end
  local fromArtifact::Union{Nothing, String} = artifactDirectory()
  return fromArtifact !== nothing && isfile(joinpath(fromArtifact, libraryFileName)) ? fromArtifact : nothing
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
      It is in the artifact $ARTIFACT_NAME (Artifacts.toml), or built by deps/build_libraries.sh
      into deps/usr/$LIBRARY_SUBDIRECTORY, or in the directory of $LIBRARY_DIRECTORY_VARIABLE."""
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
