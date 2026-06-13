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

#= Topological load order for the OMC shared libraries shipped with this
   package. Each entry only references SONAMEs of entries that appear before
   it, so dlopen'ing them in this sequence with RTLD_GLOBAL satisfies every
   DT_NEEDED reference for the dependent libraries. libModelicaCallbacks is
   first so its symbols win global resolution and override the default OMC
   setjmp/longjmp-based error handlers. =#
const _LIB_LOAD_ORDER = (
  "libModelicaCallbacks",
  "libomcgc",
  "libOpenModelicaRuntimeC",
  "libModelicaMatIO",
  "libModelicaIO",
  "libModelicaStandardTables",
  "libModelicaExternalC",
  "libSimulationRuntimeC",
)

function __init__()
  if installedLibPath === nothing
    @warn "OMRuntimeExternalC: shared libraries not found. Simulations that use external Modelica functions will fail."
    return nothing
  end
  local libdir = splitdir(installedLibPath)[1]
  push!(Libdl.DL_LOAD_PATH, libdir)
  if Sys.iswindows()
    #= Windows resolves DLL dependencies via PATH at LoadLibrary time. =#
    ENV["PATH"] = libdir * ";" * get(ENV, "PATH", "")
  end
  #= The prebuilt .so files have RUNPATH baked to the original build host,
     so ld.so cannot resolve inter-library DT_NEEDED entries on its own.
     Pre-load every dependency by absolute path in topological order with
     RTLD_GLOBAL; ld.so reuses the already-loaded library when it sees the
     same SONAME on a dependent load. =#
  local ext = Sys.iswindows() ? ".dll" : (Sys.isapple() ? ".dylib" : ".so")
  for name in _LIB_LOAD_ORDER
    local p = joinpath(libdir, name * ext)
    if isfile(p)
      try
        Libdl.dlopen(p, Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
      catch err
        @warn "OMRuntimeExternalC: failed to preload $name" path=p exception=err
      end
    end
  end
  nothing
end
#=Include Paths =#
include("pathSetup.jl")
#= Include API functions =#
include("api.jl")

end #= OMRuntimeExternalC =#
