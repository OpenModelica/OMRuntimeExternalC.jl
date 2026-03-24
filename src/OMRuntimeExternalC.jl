module OMRuntimeExternalC

import Glob
import Libdl

"""
  This function finds libraries built by the user or by the CI
"""
function locateSharedParserLibrary(directoryToSearchIn, libraryName, relativeDirectory)
  local res = Glob.glob("*",  joinpath(directoryToSearchIn, relativeDirectory))
  local results = []
  local fullLibName = "lib"
  local ext = ""
  for p in res
    push!(results, Glob.glob("*",  joinpath(directoryToSearchIn, p)))
  end
  #= Locate DLL =#
  ext = if Sys.islinux()
    ".so"
  elseif Sys.iswindows()
    ".dll"
  else #= assume apple =#
    ".dylib"
  end
  fullLibName = fullLibName * libraryName * ext
  for r in results
    for p in r
      if occursin(fullLibName, p)
        @info "Loaded shared library:" p
        return p
      end
    end
  end
  nothing
end

function __init__()
  try
    if installedLibPath !== nothing
      local libdir = splitdir(installedLibPath)[1]
      if Sys.iswindows()
        #= On Windows, add to PATH for DLL search =#
        Base._setenv("PATH", ENV["PATH"] * ";" * libdir)
      else
        #= On Linux/macOS, add to both DL_LOAD_PATH and LD_LIBRARY_PATH =#
        push!(Libdl.DL_LOAD_PATH, libdir)
        #= Also set LD_LIBRARY_PATH for library dependencies loaded by the system linker =#
        local ldpath = get(ENV, "LD_LIBRARY_PATH", "")
        ENV["LD_LIBRARY_PATH"] = isempty(ldpath) ? libdir : libdir * ":" * ldpath
      end
    end
    #= Load the Julia-compatible ModelicaCallbacks shim FIRST with RTLD_GLOBAL
       so it overrides the OMC setjmp/longjmp-based error handlers.
       Then load the other libraries with RTLD_GLOBAL so their symbols are
       visible to dlsym (used by the safe_* wrappers in the callbacks shim). =#
    if installedLibPathlibModelicaCallbacks !== nothing
      Libdl.dlopen(installedLibPathlibModelicaCallbacks, Libdl.RTLD_GLOBAL)
    end
    if installedLibPathlibModelicaIO !== nothing
      Libdl.dlopen(installedLibPathlibModelicaIO, Libdl.RTLD_GLOBAL)
    end
    if installedLibPathlibModelicaExternalC !== nothing
      Libdl.dlopen(installedLibPathlibModelicaExternalC, Libdl.RTLD_GLOBAL)
    end
  catch
    @warn "Failed to setup the environment correctly. Make sure that you have the correct shared libraries installed."
    @warn "NOTE: If your Modelica model uses certain external functions your simulation might fail."
  end
  nothing
end
#=Include Paths =#
include("pathSetup.jl")
#= Include API functions =#
include("api.jl")

end #= OMRuntimeExternalC =#
