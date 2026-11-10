#= The library libModelicaExternalC: found, loaded alone, every function the bindings call is in it. =#
import Libdl

"""
    runJulia(code::String, timeout::Float64)::Tuple{Bool, String}

Run `code` in a new Julia process with the test project (on Windows with `SetErrorMode(0x8003)`, so a
missing entry point is an error, not a dialog that waits). Returns whether the process exited with code
0 within `timeout` seconds, and its output.
"""
function runJulia(code::String, timeout::Float64)::Tuple{Bool, String}
  local prelude::String = "Sys.iswindows() && ccall(:SetErrorMode, stdcall, UInt32, (UInt32,), 0x8003)\n"
  local cmd::Cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $(prelude * code)`
  local out::Base.BufferStream = Base.BufferStream()
  local proc::Base.Process = run(pipeline(ignorestatus(cmd); stdout = out, stderr = out); wait = false)
  local status::Symbol = timedwait(() -> process_exited(proc), timeout)
  status !== :ok && kill(proc)
  close(out)
  local text::String = read(out, String)
  return (status === :ok && success(proc), text)
end

@testset "Library" begin
  local path::Union{Nothing, String} = ORC.libraryPath()

  @testset "found and loaded" begin
    @test path !== nothing
    @test isfile(path)
    @test basename(path) == ORC.libraryFileName
    @test count(l -> basename(l) == ORC.libraryFileName, Libdl.dllist()) == 1
  end

  @testset "every symbol the bindings call is in the library" begin
    local source::String = read(joinpath(@__DIR__, "..", "src", "api.jl"), String)
    local names::Vector{String} = unique([m.captures[1] for m in eachmatch(r"\(:(\w+),\s*libModelicaExternalC\)", source)])
    @test length(names) > 40
    local handle::Ptr{Cvoid} = Libdl.dlopen(path)
    local missing::Vector{String} = filter(n -> Libdl.dlsym(handle, n; throw_error = false) === nothing, names)
    @test isempty(missing)
  end

  @testset "the Modelica functions the Standard Library declares are in the library" begin
    local handle::Ptr{Cvoid} = Libdl.dlopen(path)
    for name::String in ("ModelicaInternal_mkdir", "ModelicaInternal_getenv", "ModelicaInternal_readDirectory",
                         "ModelicaStrings_scanReal", "ModelicaIO_readRealMatrix", "ModelicaFFT_kiss_fftr",
                         "ModelicaRandom_xorshift64star", "ModelicaStandardTables_CombiTimeTable_init2",
                         "ModelicaError", "ModelicaFormatMessage", "ModelicaAllocateString", "ModelicaDuplicateString")
      @test Libdl.dlsym(handle, name; throw_error = false) !== nothing
    end
  end

  @testset "only the Modelica API is exported (no zlib or matio symbols)" begin
    local handle::Ptr{Cvoid} = Libdl.dlopen(path)
    for name::String in ("inflate", "deflate", "crc32", "Mat_Open", "Mat_Close")
      #= RTLD_GLOBAL symbols of Julia's own zlib are found by a lookup in the process, not in this handle =#
      @test Libdl.dlsym(handle, name; throw_error = false) === nothing || Sys.iswindows()
    end
  end

  @testset "the environment variable names the directory" begin
    local empty::String = mktempdir()
    local fake::String = mktempdir()
    touch(joinpath(fake, ORC.libraryFileName))
    @test ORC.libraryDirectory(Dict(ORC.LIBRARY_DIRECTORY_VARIABLE => fake)) == fake
    #= a directory without the file is skipped =#
    @test ORC.libraryDirectory(Dict(ORC.LIBRARY_DIRECTORY_VARIABLE => empty)) == ORC.libraryDirectory(Dict{String, String}())
  end

  @testset "a new process loads the library and nothing else (no omc runtime, no gettext)" begin
    local code::String = """
      import Libdl
      before = Set(Libdl.dllist())
      import OMRuntimeExternalC
      #= the package image (the native code of the precompile cache) is not a library of the package =#
      added = sort!(filter(p -> !occursin("compiled", p), collect(setdiff(Set(Libdl.dllist()), before))))
      foreach(p -> println("ADDED ", basename(p)), added)
      println("OK")
      """
    local result::Tuple{Bool, String} = runJulia(code, 600.0)
    result[1] || println(result[2])
    @test result[1]
    local added::Vector{String} = [strip(l[7:end]) for l in split(result[2], '\n') if startswith(l, "ADDED ")]
    @test added == [ORC.libraryFileName]
  end

  @testset "OMRuntimeExternalC, then Glib_jll, in a new process (OMBackend.jl#101)" begin
    local code::String = """
      import OMRuntimeExternalC
      import Glib_jll
      println("OK")
      """
    local result::Tuple{Bool, String} = runJulia(code, 600.0)
    result[1] || println(result[2])
    @test result[1]
    @test occursin("OK", result[2])
  end
end
