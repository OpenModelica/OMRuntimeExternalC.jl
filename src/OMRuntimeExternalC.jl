module OMRuntimeExternalC

import Glob
import Libdl
@static if Sys.iswindows()
  #= Windows only: Linux and macOS processes load what they loaded before. =#
  import Libiconv_jll
  import GettextRuntime_jll
end

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

"""
    sharedRuntimeLibraries()::Vector{String}

Paths of the JLL libraries that `__init__` loads before the package's own libraries.

On Windows: Libiconv_jll's `libiconv-2.dll` and GettextRuntime_jll's `libintl-8.dll`. The bundle in
`lib/ext/shared/x86_64-mingw32` has its own copies of both (`libOpenModelicaRuntimeC.dll` ->
`libsystre-0.dll` -> `libtre-5.dll` -> `libintl-8.dll` -> `libiconv-2.dll`). Windows binds a DLL import to the
module of that name already in the process, so the first copy loaded serves every later library. The bundled
`libintl-8.dll` lacks `DllMain` and `wcrtomb`, which Glib_jll's libraries import from it: loaded first, it broke
every later load of Glib (OpenModelica/OMBackend.jl#101). The JLLs' copies export everything `libtre-5.dll`
imports (`libintl_gettext`), so the process has one gettext runtime, Glib's, whatever the package load order.

Empty on Linux and macOS.
"""
function sharedRuntimeLibraries()::Vector{String}
  @static if Sys.iswindows()
    return String[Libiconv_jll.get_libiconv_path(), GettextRuntime_jll.get_libintl_path()]
  else
    return String[]
  end
end

"""
    libraryLoadOrder(libdir::String, ext::String, shared::Vector{String})::Vector{String}

The libraries `__init__` loads, in this order: `shared` (see `sharedRuntimeLibraries`), then the entries of
`_LIB_LOAD_ORDER` that exist in `libdir` with the extension `ext`.
"""
function libraryLoadOrder(libdir::String, ext::String, shared::Vector{String})::Vector{String}
  local order::Vector{String} = copy(shared)
  for name::String in _LIB_LOAD_ORDER
    local p::String = joinpath(libdir, name * ext)
    if isfile(p)
      push!(order, p)
    end
  end
  return order
end

function __init__()
  if installedLibPath === nothing
    @warn "OMRuntimeExternalC: shared libraries not found. Simulations that use external Modelica functions will fail."
    return nothing
  end
  local libdir::String = splitdir(installedLibPath)[1]
  push!(Libdl.DL_LOAD_PATH, libdir)
  if Sys.iswindows()
    #= Windows resolves DLL dependencies via PATH at LoadLibrary time. =#
    ENV["PATH"] = libdir * ";" * get(ENV, "PATH", "")
  end
  #= The prebuilt .so files have RUNPATH baked to the original build host,
     so ld.so cannot resolve inter-library DT_NEEDED entries on its own.
     Pre-load every dependency by absolute path in topological order with
     RTLD_GLOBAL; ld.so reuses the already-loaded library when it sees the
     same SONAME on a dependent load. On Windows the JLLs' gettext runtime
     comes first (sharedRuntimeLibraries). =#
  local ext::String = Sys.iswindows() ? ".dll" : (Sys.isapple() ? ".dylib" : ".so")
  for p::String in libraryLoadOrder(libdir, ext, sharedRuntimeLibraries())
    try
      Libdl.dlopen(p, Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    catch err
      @warn "OMRuntimeExternalC: failed to preload $(basename(p))" path=p exception=err
    end
  end
  nothing
end
#=Include Paths =#
include("pathSetup.jl")
#= Include API functions =#
include("api.jl")

end #= OMRuntimeExternalC =#
