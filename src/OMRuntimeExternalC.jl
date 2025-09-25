module OMRuntimeExternalC

import Glob

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
  local sep = Sys.iswindows() ? ';' : ':'
  try
    Base._setenv("PATH", ENV["PATH"] * sep * splitdir(installedLibPath)[1])
  catch
    @warn "Failed to setup the environment correctly. Make sure that you have the correct shared libraries installed."
    @warn "NOTE: If your Modelica model use certain premade functions your simulation might fail. However, you may still use this software for other models that does not make use of these constructs."
  end
  nothing
end
#=Include Paths =#
include("pathSetup.jl")
#= Include API functions =#
include("api.jl")

end #= OMRuntimeExternalC =#
