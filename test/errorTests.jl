#= A Modelica error (ModelicaError, ModelicaFormatError in the C code) is a Julia error of the ccall that
   was running: the process goes on, and the library works afterwards. =#
import Libdl

"""
    errorMessage(f::Function)::String

The message of the `ErrorException` that `f()` throws, `""` if it throws nothing or something else.
"""
function errorMessage(f::Function)::String
  try
    f()
  catch e
    return e isa ErrorException ? e.msg : ""
  end
  return ""
end

"""
    noExtrapolationTable()::ORC.ExternalCombiTimeTable

A time table over [0, 2] (`[0 0; 1 10; 2 20]`, linear segments) that reports an error outside its range
(extrapolation 4, NoExtrapolation).
"""
function noExtrapolationTable()::ORC.ExternalCombiTimeTable
  local table::Matrix{Float64} = [0.0 0.0; 1.0 10.0; 2.0 20.0]
  return ORC.ModelicaStandardTables_CombiTimeTable_init2("NoName", "NoName", table, 3, 2, 0.0, [2], 1, 1, 4, 0.0, 1, 0)
end

@testset "Modelica errors are Julia errors" begin
  local table::Matrix{Float64} = [0.0 0.0; 1.0 10.0; 2.0 20.0]

  @testset "a function called directly (no safe_* entry)" begin
    local missingFile::String = joinpath(mktempdir(), "noSuchFile.txt")
    local message::String = errorMessage() do
      ORC.ModelicaStandardTables_CombiTimeTable_init2(missingFile, "tab", table, 3, 2, 0.0, [2], 1, 1, 2, 0.0, 1, 0)
    end
    @test startswith(message, "Modelica runtime error: Not possible to open file")
    @test occursin("noSuchFile.txt", message)

    message = errorMessage(() -> ORC.ModelicaInternal_removeFile(joinpath(mktempdir(), "noSuchDirectory", "file")))
    @test startswith(message, "Modelica runtime error: Not possible to remove file")
  end

  @testset "the table works after its error" begin
    local id::ORC.ExternalCombiTimeTable = noExtrapolationTable()
    @test ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 0.5, 100.0, 0.0) ≈ 5.0
    local message::String = errorMessage(() -> ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 5.0, 100.0, 0.0))
    @test startswith(message, "Modelica runtime error: Extrapolation error")
    @test ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 1.5, 100.0, 0.0) ≈ 15.0
    ORC.ModelicaStandardTables_CombiTimeTable_close(id)
  end

  @testset "ModelicaError and ModelicaFormatError called as compiled C code of a model calls them" begin
    local handle::Ptr{Cvoid} = Libdl.dlopen(ORC.libraryPath())
    local modelicaError::Ptr{Cvoid} = Libdl.dlsym(handle, :ModelicaError)
    local modelicaFormatError::Ptr{Cvoid} = Libdl.dlsym(handle, :ModelicaFormatError)
    @test errorMessage(() -> ccall(modelicaError, Cvoid, (Cstring,), "from C")) == "Modelica runtime error: from C"
    local message::String = errorMessage() do
      ccall(modelicaFormatError, Cvoid, (Cstring, Cstring...), "%s has %s", "the model", "an error")
    end
    @test message == "Modelica runtime error: the model has an error"
    #= a message longer than the buffer of the shim (4096 bytes) is cut, not written past the end =#
    message = errorMessage(() -> ccall(modelicaError, Cvoid, (Cstring,), repeat("x", 10000)))
    @test startswith(message, "Modelica runtime error: xxx")
    @test 4000 < length(message) < 4200
  end

  @testset "a safe_* entry reports its own error, before and after an error of the handler" begin
    local missingFile::String = joinpath(mktempdir(), "noSuchFile.mat")
    local before::String = errorMessage(() -> ORC.ModelicaIO_readMatrixSizes(missingFile, "m"))
    @test startswith(before, "ModelicaIO_readMatrixSizes failed")
    @test errorMessage(() -> ORC.ModelicaInternal_removeFile(missingFile)) != ""
    @test errorMessage(() -> ORC.ModelicaIO_readMatrixSizes(missingFile, "m")) == before
  end

  @testset "1000 errors in a row, then on another task" begin
    local id::ORC.ExternalCombiTimeTable = noExtrapolationTable()
    local thrown::Int = 0
    for _ in 1:1000
      thrown += errorMessage(() -> ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 5.0, 100.0, 0.0)) != ""
    end
    @test thrown == 1000
    local task::Task = Threads.@spawn ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 5.0, 100.0, 0.0)
    @test_throws TaskFailedException fetch(task)
    @test ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 0.25, 100.0, 0.0) ≈ 2.5
    ORC.ModelicaStandardTables_CombiTimeTable_close(id)
  end
end
