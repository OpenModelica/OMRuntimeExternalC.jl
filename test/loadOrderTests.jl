#= The process has one gettext runtime, the JLLs', whatever the package load order (OpenModelica/OMBackend.jl#101). =#
import Libdl

"""
    loadGlibAfter(timeout::Float64)::Tuple{Bool, String}

Load OMRuntimeExternalC, then Glib_jll, in a new Julia process (on Windows with `SetErrorMode(0x8003)`, so a missing
entry point is an error, not a dialog that waits). Returns whether the process printed `OK` and exited with code 0
within `timeout` seconds, and its output. Each line before `OK` is a loaded library named `libintl-8.dll`.
"""
function loadGlibAfter(timeout::Float64)::Tuple{Bool, String}
  local code::String = """
    Sys.iswindows() && ccall(:SetErrorMode, stdcall, UInt32, (UInt32,), 0x8003)
    import OMRuntimeExternalC
    import Glib_jll
    import Libdl
    foreach(println, filter(p -> lowercase(basename(p)) == "libintl-8.dll", Libdl.dllist()))
    println("OK")
    """
  local cmd::Cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $code`
  local out::Base.BufferStream = Base.BufferStream()
  local proc::Base.Process = run(pipeline(ignorestatus(cmd); stdout = out, stderr = out); wait = false)
  local status::Symbol = timedwait(() -> process_exited(proc), timeout)
  if status !== :ok
    kill(proc)
  end
  close(out)
  local text::String = read(out, String)
  return (status === :ok && success(proc) && occursin("OK", text), text)
end

@testset "Library load order (OMBackend.jl#101)" begin
  local shared::Vector{String} = ORC.sharedRuntimeLibraries()
  @testset "sharedRuntimeLibraries" begin
    if Sys.iswindows()
      @test map(basename, shared) == ["libiconv-2.dll", "libintl-8.dll"]
      @test all(isfile, shared)
    else
      @test isempty(shared)
      #= Linux and macOS: the gettext JLLs are not loaded. =#
      @test !any(k -> k.name in ("GettextRuntime_jll", "Libiconv_jll"), keys(Base.loaded_modules))
    end
  end

  @testset "libraryLoadOrder: JLL runtime first, bundled gettext never" begin
    local dir::String = mktempdir()
    for name::String in ("libModelicaIO", "libModelicaCallbacks", "libintl-8", "libiconv-2")
      touch(joinpath(dir, name * ".dll"))
    end
    local jll::Vector{String} = ["/jll/bin/libiconv-2.dll", "/jll/bin/libintl-8.dll"]
    local order::Vector{String} = ORC.libraryLoadOrder(dir, ".dll", jll)
    @test order == [jll; joinpath(dir, "libModelicaCallbacks.dll"); joinpath(dir, "libModelicaIO.dll")]
    @test !any(p -> startswith(p, dir) && occursin(r"libintl|libiconv", p), order)
    @test ORC.libraryLoadOrder(dir, ".dll", String[]) == order[3:end]
  end

  @testset "OMRuntimeExternalC, then Glib_jll, in a new process" begin
    local result::Tuple{Bool, String} = loadGlibAfter(600.0)
    local ok::Bool = result[1]
    local text::String = result[2]
    ok || println(text)
    @test ok
    if Sys.iswindows() && ORC.installedLibPath !== nothing
      local libdir::String = dirname(ORC.installedLibPath)
      local libintl::Vector{String} = filter(l -> endswith(lowercase(l), "libintl-8.dll"), split(text, '\n'))
      @test length(libintl) == 1
      @test !any(l -> startswith(lowercase(l), lowercase(libdir)), libintl)
    end
  end
end
