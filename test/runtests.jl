using Test
import OMRuntimeExternalC

const ORC = OMRuntimeExternalC

@testset "OMRuntimeExternalC.jl" begin

  @testset "CombiTable1D with Matrix input" begin
    local table::Matrix{Float64} = [
      1990.0 6.107;
      1991.0 6.199;
      1992.0 6.082;
      1993.0 6.086;
      1994.0 6.203;
      1995.0 6.335;
      1996.0 6.463;
      1997.0 6.574;
      1998.0 6.541;
      1999.0 6.523;
      2000.0 6.686
    ]
    local columns = [2]
    local smoothness = 1  #= LinearSegments =#
    local extrapolation = 2  #= LastTwoPoints =#
    local verbose = 1

    local tableID = ORC.ModelicaStandardTables_CombiTable1D_init2(
      "NoName", "NoName",
      table, size(table, 1), size(table, 2),
      columns, length(columns),
      smoothness, extrapolation, verbose
    )

    @testset "init2 returns valid pointer" begin
      @test tableID isa Ptr{Nothing}
      @test tableID != C_NULL
    end

    @testset "minimumAbscissa" begin
      @test ORC.ModelicaStandardTables_CombiTable1D_minimumAbscissa(tableID) == 1990.0
    end

    @testset "maximumAbscissa" begin
      @test ORC.ModelicaStandardTables_CombiTable1D_maximumAbscissa(tableID) == 2000.0
    end

    @testset "getValue - interpolation" begin
      #= Value at exact point =#
      val_1990 = ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 1990.0)
      @test isapprox(val_1990, 6.107, atol=1e-6)

      #= Interpolated value between 1990 and 1991 =#
      val_mid = ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 1990.5)
      @test val_mid > 6.107 && val_mid < 6.199
    end

    @testset "getValue - extrapolation" begin
      #= Value before table start (extrapolated) =#
      val_before = ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 1985.0)
      @test val_before < 6.107  #= Should extrapolate below =#

      #= Value after table end (extrapolated) =#
      val_after = ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 2005.0)
      @test val_after > 6.686  #= Should extrapolate above =#
    end

    @testset "getDerValue" begin
      der_val = ORC.ModelicaStandardTables_CombiTable1D_getDerValue(tableID, 1, 1990.5, 1.0)
      #= Derivative should be approximately (6.199 - 6.107) / (1991 - 1990) = 0.092 =#
      @test isapprox(der_val, 0.092, atol=0.01)
    end

    @testset "close" begin
      @test begin
        ORC.ModelicaStandardTables_CombiTable1D_close(tableID)
        true
      end
    end
  end

  @testset "CombiTable1D with Vector{Vector} input" begin
    local vecVec::Vector{Vector{Float64}} = [
      [1.0, 10.0],
      [2.0, 20.0],
      [3.0, 30.0],
      [4.0, 40.0],
      [5.0, 50.0]
    ]
    local columns = [2]
    local smoothness = 1
    local extrapolation = 2
    local verbose = true

    local tableID = ORC.ModelicaStandardTables_CombiTable1D_init2(
      "NoName", "NoName",
      vecVec, 5, 2,
      columns, 1,
      smoothness, extrapolation, verbose
    )

    @testset "init2 returns valid pointer" begin
      @test tableID isa Ptr{Nothing}
      @test tableID != C_NULL
    end

    @testset "minimumAbscissa" begin
      @test ORC.ModelicaStandardTables_CombiTable1D_minimumAbscissa(tableID) == 1.0
    end

    @testset "maximumAbscissa" begin
      @test ORC.ModelicaStandardTables_CombiTable1D_maximumAbscissa(tableID) == 5.0
    end

    @testset "getValue - linear interpolation" begin
      #= For linear data y = 10*x, interpolation should be exact =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 1.0), 10.0, atol=1e-6)
      @test isapprox(ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 2.5), 25.0, atol=1e-6)
      @test isapprox(ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 3.0), 30.0, atol=1e-6)
    end

    @testset "getDerValue - constant slope" begin
      #= For y = 10*x, derivative should be 10 everywhere =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTable1D_getDerValue(tableID, 1, 2.0, 1.0), 10.0, atol=1e-6)
      @test isapprox(ORC.ModelicaStandardTables_CombiTable1D_getDerValue(tableID, 1, 4.0, 1.0), 10.0, atol=1e-6)
    end

    @testset "close" begin
      @test begin
        ORC.ModelicaStandardTables_CombiTable1D_close(tableID)
        true
      end
    end
  end

  @testset "ModelicaStrings functions" begin
    @testset "ModelicaStrings_length" begin
      @test ORC.ModelicaStrings_length("") == 0
      @test ORC.ModelicaStrings_length("a") == 1
      @test ORC.ModelicaStrings_length("abc") == 3
      @test ORC.ModelicaStrings_length("hello world") == 11
      @test ORC.ModelicaStrings_length("OpenModelica") == 12
    end

    @testset "ModelicaStrings_skipWhiteSpace" begin
      #= No leading whitespace =#
      @test ORC.ModelicaStrings_skipWhiteSpace("hello", 1) == 1

      #= Leading spaces =#
      @test ORC.ModelicaStrings_skipWhiteSpace("   hello", 1) == 4

      #= Leading tabs =#
      @test ORC.ModelicaStrings_skipWhiteSpace("\t\thello", 1) == 3

      #= Mixed whitespace =#
      @test ORC.ModelicaStrings_skipWhiteSpace("  \t hello", 1) == 5

      #= Start from middle of string =#
      @test ORC.ModelicaStrings_skipWhiteSpace("ab   cd", 3) == 6

      #= All whitespace =#
      @test ORC.ModelicaStrings_skipWhiteSpace("   ", 1) == 4
    end
  end

end
