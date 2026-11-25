# Tests of the parts of src/api.jl the other test sets do not reach: the init3 constructors of
# MSL 4.1, second derivatives, read, the error branch of the derivative getters, the AD-safe
# overloads, and the output-by-reference overloads of the string and file functions.
# Author: John Tinnerholm

"""
    PrimalCarrier(value)

A `Real` that keeps its primal in the field `value`, as `ForwardDiff.Dual` does.
"""
struct PrimalCarrier <: Real
  value::Float64
end

@testset "api.jl" begin
  local table::Matrix{Float64} = [0.0 0.0; 1.0 10.0; 2.0 20.0; 3.0 30.0; 4.0 40.0]
  local rows::Vector{Vector{Float64}} = [table[i, :] for i in 1:size(table, 1)]
  #= z(u1, u2) = u1 + u2: linear in each argument =#
  local table2D::Matrix{Float64} = [0.0 1.0 2.0 3.0; 10.0 11.0 12.0 13.0; 20.0 21.0 22.0 23.0]

  @testset "CombiTimeTable init3, matrix and rows" begin
    for tab in (table, rows)
      local id = ORC.ModelicaStandardTables_CombiTimeTable_init3(
        "NoName", "NoName", tab, 5, 2, 0.0, [2], 1,
        1, 2, 0.0, 1, 0, ",", 0)
      @test id != C_NULL
      @test ORC.ModelicaStandardTables_CombiTimeTable_minimumTime(id) == 0.0
      @test ORC.ModelicaStandardTables_CombiTimeTable_maximumTime(id) == 4.0
      @test ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, 1, 2.5, 3.0, 3.0) ≈ 25.0
      @test ORC.ModelicaStandardTables_CombiTimeTable_read(id, 1, 0) == 1.0
      ORC.ModelicaStandardTables_CombiTimeTable_close(id)
    end
  end

  @testset "CombiTimeTable derivatives, Float64 and AD-safe overloads" begin
    local id = ORC.ModelicaStandardTables_CombiTimeTable_init2(
      "NoName", "NoName", table, 5, 2, 0.0, [2], 1, 1, 2, 0.0, 1, 0)
    local p(x::Float64)::PrimalCarrier = PrimalCarrier(x)
    @test ORC.ModelicaStandardTables_CombiTimeTable_getValue(id, Int32(1), p(2.5), p(3.0), p(3.0)) ≈ 25.0
    @test ORC.ModelicaStandardTables_CombiTimeTable_getDerValue(id, Int32(1), p(2.5), p(3.0), p(3.0), p(1.0)) ≈ 10.0
    @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getDer2Value(id, 1, 2.5, 3.0, 3.0, 1.0, 0.0), 0.0; atol = 1e-9)
    @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getDer2Value(id, Int32(1), p(2.5), p(3.0), p(3.0), p(1.0), 0), 0.0;
                   atol = 1e-9)
    ORC.ModelicaStandardTables_CombiTimeTable_close(id)
  end

  @testset "a derivative the C code rejects (NoExtrapolation): the error is logged, the value is 0" begin
    local noExtrapolation::Int64 = 4
    local id1 = ORC.ModelicaStandardTables_CombiTable1D_init2("NoName", "NoName", table, 5, 2, [2], 1, 1, noExtrapolation, 0)
    @test (@test_logs (:error, r"CombiTable1D_getDerValue") match_mode = :any ORC.ModelicaStandardTables_CombiTable1D_getDerValue(id1, 1, 10.0, 1.0)) == 0
    @test (@test_logs (:error, r"CombiTable1D_getDer2Value") match_mode = :any ORC.ModelicaStandardTables_CombiTable1D_getDer2Value(id1, 1, 10.0, 1.0, 0.0)) == 0
    ORC.ModelicaStandardTables_CombiTable1D_close(id1)
    local idT = ORC.ModelicaStandardTables_CombiTimeTable_init2("NoName", "NoName", table, 5, 2, 0.0, [2], 1, 1, noExtrapolation, 0.0, 1, 0)
    @test (@test_logs (:error, r"CombiTimeTable_getDerValue") match_mode = :any ORC.ModelicaStandardTables_CombiTimeTable_getDerValue(idT, 1, 10.0, 1.0e60, 1.0e60, 1.0)) == 0
    @test (@test_logs (:error, r"CombiTimeTable_getDer2Value") match_mode = :any ORC.ModelicaStandardTables_CombiTimeTable_getDer2Value(idT, 1, 10.0, 1.0e60, 1.0e60, 1.0, 0.0)) == 0
    ORC.ModelicaStandardTables_CombiTimeTable_close(idT)
    local id2 = ORC.ModelicaStandardTables_CombiTable2D_init2("NoName", "NoName", table2D, 3, 4, 1, noExtrapolation, 0)
    @test (@test_logs (:error, r"CombiTable2D_getDerValue") match_mode = :any ORC.ModelicaStandardTables_CombiTable2D_getDerValue(id2, 99.0, 1.5, 1.0, 1.0)) == 0
    @test (@test_logs (:error, r"CombiTable2D_getDer2Value") match_mode = :any ORC.ModelicaStandardTables_CombiTable2D_getDer2Value(id2, 99.0, 1.5, 1.0, 1.0, 0.0, 0.0)) == 0
    ORC.ModelicaStandardTables_CombiTable2D_close(id2)
  end

  @testset "CombiTable1D init3 and read" begin
    for tab in (table, rows)
      local id = ORC.ModelicaStandardTables_CombiTable1D_init3("NoName", "NoName", tab, 5, 2, [2], 1, 1, 2, 0, ",", 0)
      @test id != C_NULL
      @test ORC.ModelicaStandardTables_CombiTable1D_getValue(id, 1, 1.5) ≈ 15.0
      @test ORC.ModelicaStandardTables_CombiTable1D_read(id, 1, 0) == 1.0
      ORC.ModelicaStandardTables_CombiTable1D_close(id)
    end
  end

  @testset "CombiTable2D init3, read, second derivative" begin
    local rows2D::Vector{Vector{Float64}} = [table2D[i, :] for i in 1:size(table2D, 1)]
    for tab in (table2D, rows2D)
      local id = ORC.ModelicaStandardTables_CombiTable2D_init3("NoName", "NoName", tab, 3, 4, 1, 2, 0, ",", 0)
      @test id != C_NULL
      @test ORC.ModelicaStandardTables_CombiTable2D_getValue(id, 15.0, 1.5) ≈ 16.5
      @test ORC.ModelicaStandardTables_CombiTable2D_read(id, 1, 0) == 1.0
      @test isapprox(ORC.ModelicaStandardTables_CombiTable2D_getDer2Value(id, 15.0, 1.5, 1.0, 1.0, 0.0, 0.0), 0.0; atol = 1e-9)
      ORC.ModelicaStandardTables_CombiTable2D_close(id)
    end
    @test ORC._tableRowMajor(Vector{Float64}[]) == Float64[]
  end

  @testset "string functions: overloads" begin
    @test ORC.ModelicaStrings_compare("abc", "ABC", false) == ORC.ModelicaStrings_compare("abc", "abc", true)
    @test ORC.ModelicaStrings_compare("abc", "ABC", true) != ORC.ModelicaStrings_compare("abc", "abc", true)
    local (next, text) = ORC.ModelicaStrings_scanString("  \"quoted\" rest", 1)
    @test text == "quoted"
    @test next == 11
    @test ORC.ModelicaStrings_scanString("no string here", 1)[2] == ""
    local nextIndex = Ref{Cint}(0)
    local number = Ref{Cdouble}(0.0)
    ORC.ModelicaStrings_scanReal(SubString(" 2.5e1 x", 1), 1, 0, nextIndex, number)
    @test number[] == 25.0
    @test nextIndex[] == 7
  end

  @testset "readLine with the end-of-file output argument" begin
    local file::String = tempname()
    write(file, "first\nsecond\n")
    local eofRef = Ref{Cint}(-1)
    @test ORC.ModelicaInternal_readLine(SubString(file, 1), Int32(1), eofRef) == "first"
    @test eofRef[] == 0
    local eofVector = Cint[-1]
    @test ORC.ModelicaInternal_readLine(file, 3, eofVector) == ""
    @test eofVector[1] == 1
    @test ORC.ModelicaInternal_readLine(file, 2, nothing) == "second"
    #= the C code keeps the file open after a line before its end (Windows cannot delete an open file) =#
    ORC.ModelicaStreams_closeFile(file)
    rm(file)
  end

  @testset "ModelicaError(::String) throws" begin
    @test_throws ErrorException("Modelica runtime error: boom") ORC.ModelicaError("boom")
  end

  @testset "initial xorshift64* state of length 1" begin
    local s1 = ORC._initialStateWithXorshift64star(1, 2, 1)
    @test length(s1) == 1
    @test s1[1] == ORC._initialStateWithXorshift64star(1, 2, 2)[1]
  end
end
