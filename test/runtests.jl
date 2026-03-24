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

  @testset "CombiTable1D getDer2Value" begin
    local table::Matrix{Float64} = [
      1.0 10.0;
      2.0 20.0;
      3.0 30.0;
      4.0 40.0;
      5.0 50.0
    ]
    local columns = [2]
    local tableID = ORC.ModelicaStandardTables_CombiTable1D_init2(
      "NoName", "NoName",
      table, size(table, 1), size(table, 2),
      columns, length(columns),
      1, 2, 1
    )
    #= For linear data, second derivative should be 0 =#
    @test isapprox(ORC.ModelicaStandardTables_CombiTable1D_getDer2Value(tableID, 1, 2.5, 1.0, 0.0), 0.0, atol=1e-6)
    ORC.ModelicaStandardTables_CombiTable1D_close(tableID)
  end

  @testset "CombiTimeTable" begin
    #= Time table: columns are [time, value]. Linear data: value = 10*time =#
    local table::Matrix{Float64} = [
      0.0 0.0;
      1.0 10.0;
      2.0 20.0;
      3.0 30.0;
      4.0 40.0;
      5.0 50.0
    ]
    local columns = [2]
    local smoothness = 1  #= LinearSegments =#
    local extrapolation = 2  #= LastTwoPoints =#

    local tableID = ORC.ModelicaStandardTables_CombiTimeTable_init2(
      "NoName", "NoName",
      table, size(table, 1), size(table, 2),
      0.0,  #= startTime =#
      columns, length(columns),
      smoothness, extrapolation,
      0.0,  #= shiftTime =#
      1,    #= timeEvents =#
      0     #= verbose =#
    )

    @testset "init2 returns valid pointer" begin
      @test tableID isa Ptr{Nothing}
      @test tableID != C_NULL
    end

    @testset "minimumTime" begin
      @test ORC.ModelicaStandardTables_CombiTimeTable_minimumTime(tableID) == 0.0
    end

    @testset "maximumTime" begin
      @test ORC.ModelicaStandardTables_CombiTimeTable_maximumTime(tableID) == 5.0
    end

    @testset "getValue" begin
      #= nextTimeEvent and preNextTimeEvent set to large values for simple interpolation =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getValue(tableID, 1, 0.0, 1e10, 1e10), 0.0, atol=1e-6)
      @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getValue(tableID, 1, 2.5, 1e10, 1e10), 25.0, atol=1e-6)
      @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getValue(tableID, 1, 5.0, 1e10, 1e10), 50.0, atol=1e-6)
    end

    @testset "getDerValue" begin
      #= For y = 10*t, derivative should be 10 everywhere =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getDerValue(tableID, 1, 2.0, 1e10, 1e10, 1.0), 10.0, atol=1e-6)
    end

    @testset "nextTimeEvent" begin
      #= For linear segments with no events, nextTimeEvent returns a large number =#
      nte = ORC.ModelicaStandardTables_CombiTimeTable_nextTimeEvent(tableID, 0.0)
      @test nte > 0.0
    end

    @testset "close" begin
      @test begin
        ORC.ModelicaStandardTables_CombiTimeTable_close(tableID)
        true
      end
    end
  end

  @testset "CombiTimeTable with Vector{Vector} input" begin
    local vecVec::Vector{Vector{Float64}} = [
      [0.0, 100.0],
      [1.0, 200.0],
      [2.0, 300.0]
    ]
    local columns = [2]

    local tableID = ORC.ModelicaStandardTables_CombiTimeTable_init2(
      "NoName", "NoName",
      vecVec, 3, 2,
      0.0, columns, 1,
      1, 2, 0.0, 1, 0
    )

    @test tableID isa Ptr{Nothing}
    @test tableID != C_NULL
    @test isapprox(ORC.ModelicaStandardTables_CombiTimeTable_getValue(tableID, 1, 0.5, 1e10, 1e10), 150.0, atol=1e-6)
    ORC.ModelicaStandardTables_CombiTimeTable_close(tableID)
  end

  @testset "CombiTable2D" begin
    #= 2D table layout:
       First row (after [0,0]) = u2 breakpoints: 1.0, 2.0, 3.0
       First column = u1 breakpoints: 10.0, 20.0
       Body = z(u1, u2) = u1 * u2
    =#
    local table::Matrix{Float64} = [
      0.0  1.0  2.0   3.0;
      10.0 10.0 20.0  30.0;
      20.0 20.0 40.0  60.0
    ]
    local smoothness = 1  #= LinearSegments =#
    local extrapolation = 2  #= LastTwoPoints =#

    local tableID = ORC.ModelicaStandardTables_CombiTable2D_init2(
      "NoName", "NoName",
      table, size(table, 1), size(table, 2),
      smoothness, extrapolation, 0
    )

    @testset "init2 returns valid pointer" begin
      @test tableID isa Ptr{Nothing}
      @test tableID != C_NULL
    end

    @testset "getValue" begin
      #= Exact grid point: z(10, 2) = 20 =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTable2D_getValue(tableID, 10.0, 2.0), 20.0, atol=1e-6)
      #= Exact grid point: z(20, 3) = 60 =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTable2D_getValue(tableID, 20.0, 3.0), 60.0, atol=1e-6)
      #= Interpolated: z(15, 2) should be 30 (midpoint between 20 and 40) =#
      @test isapprox(ORC.ModelicaStandardTables_CombiTable2D_getValue(tableID, 15.0, 2.0), 30.0, atol=1e-6)
    end

    @testset "minimumAbscissa" begin
      (u1Min, u2Min) = ORC.ModelicaStandardTables_CombiTable2D_minimumAbscissa(tableID)
      @test u1Min == 10.0
      @test u2Min == 1.0
    end

    @testset "maximumAbscissa" begin
      (u1Max, u2Max) = ORC.ModelicaStandardTables_CombiTable2D_maximumAbscissa(tableID)
      @test u1Max == 20.0
      @test u2Max == 3.0
    end

    @testset "getDerValue" begin
      #= Partial derivative dz/du1 at (15, 2) with der_u1=1, der_u2=0
         dz/du1 = u2 = 2, so total = 2*1 + 0 = 2 =#
      der = ORC.ModelicaStandardTables_CombiTable2D_getDerValue(tableID, 15.0, 2.0, 1.0, 0.0)
      @test isapprox(der, 2.0, atol=1e-6)
    end

    @testset "close" begin
      @test begin
        ORC.ModelicaStandardTables_CombiTable2D_close(tableID)
        true
      end
    end
  end

  @testset "CombiTable2D with Vector{Vector} input" begin
    local vecVec::Vector{Vector{Float64}} = [
      [0.0,  1.0,  2.0],
      [10.0, 10.0, 20.0],
      [20.0, 20.0, 40.0]
    ]

    local tableID = ORC.ModelicaStandardTables_CombiTable2D_init2(
      "NoName", "NoName",
      vecVec, 3, 3,
      1, 2, 0
    )

    @test tableID isa Ptr{Nothing}
    @test tableID != C_NULL
    @test isapprox(ORC.ModelicaStandardTables_CombiTable2D_getValue(tableID, 10.0, 1.0), 10.0, atol=1e-6)
    @test isapprox(ORC.ModelicaStandardTables_CombiTable2D_getValue(tableID, 15.0, 1.5), 22.5, atol=1e-6)
    ORC.ModelicaStandardTables_CombiTable2D_close(tableID)
  end

  @testset "ModelicaIO functions" begin
    local testMatFile = tempname() * ".mat"

    @testset "writeRealMatrix and readMatrixSizes" begin
      local mat = [1.0 2.0 3.0; 4.0 5.0 6.0]  #= 2x3 matrix =#
      res = ORC.ModelicaIO_writeRealMatrix(testMatFile, "testMatrix", mat)
      @test res == 1  #= C function returns 1 on success =#
      @test isfile(testMatFile)

      dims = ORC.ModelicaIO_readMatrixSizes(testMatFile, "testMatrix")
      @test dims == [2, 3]
    end

    @testset "readRealMatrix" begin
      local mat = ORC.ModelicaIO_readRealMatrix(testMatFile, "testMatrix", Int64(2), Int64(3))
      @test size(mat) == (2, 3)
      @test isapprox(mat[1, 1], 1.0, atol=1e-10)
      @test isapprox(mat[1, 2], 2.0, atol=1e-10)
      @test isapprox(mat[1, 3], 3.0, atol=1e-10)
      @test isapprox(mat[2, 1], 4.0, atol=1e-10)
      @test isapprox(mat[2, 2], 5.0, atol=1e-10)
      @test isapprox(mat[2, 3], 6.0, atol=1e-10)
    end

    @testset "writeRealMatrix separate file" begin
      local f2 = tempname() * ".mat"
      res = ORC.ModelicaIO_writeRealMatrix(f2, "secondMatrix", [10.0 20.0; 30.0 40.0])
      @test res == 1  #= C function returns 1 on success =#

      dims2 = ORC.ModelicaIO_readMatrixSizes(f2, "secondMatrix")
      @test dims2 == [2, 2]

      mat2 = ORC.ModelicaIO_readRealMatrix(f2, "secondMatrix", Int64(2), Int64(2))
      @test isapprox(mat2[1, 1], 10.0, atol=1e-10)
      @test isapprox(mat2[2, 2], 40.0, atol=1e-10)
      rm(f2, force=true)
    end

    @testset "roundtrip with 1x1 matrix" begin
      local f = tempname() * ".mat"
      ORC.ModelicaIO_writeRealMatrix(f, "scalar", [42.0;;])
      dims = ORC.ModelicaIO_readMatrixSizes(f, "scalar")
      @test dims == [1, 1]
      mat = ORC.ModelicaIO_readRealMatrix(f, "scalar", Int64(1), Int64(1))
      @test isapprox(mat[1, 1], 42.0, atol=1e-10)
      rm(f, force=true)
    end

    rm(testMatFile, force=true)
  end

  @testset "ModelicaInternal functions" begin
    @testset "ModelicaInternal_fullPathName" begin
      p = ORC.ModelicaInternal_fullPathName(".")
      @test isabspath(p)
      @test isdir(p)
    end

    @testset "ModelicaInternal_stat" begin
      #= Modelica FileType enum: 1=NoFile, 2=RegularFile, 3=Directory, 4=SpecialFile =#
      @test ORC.ModelicaInternal_stat(@__FILE__) == 2   #= RegularFile =#
      @test ORC.ModelicaInternal_stat(@__DIR__) == 3    #= Directory =#
      @test ORC.ModelicaInternal_stat("/nonexistent_path_12345") == 1  #= NoFile =#
    end

    @testset "ModelicaInternal_print and readLine and countLines" begin
      local f = tempname()
      #= Write two lines using Julia IO to have a known file format =#
      open(f, "w") do io
        println(io, "line one")
        println(io, "line two")
      end

      @test ORC.ModelicaInternal_countLines(f) == 2

      (line1, eof1) = ORC.ModelicaInternal_readLine(f, Int64(1))
      @test line1 == "line one"
      @test eof1 == false

      (line2, eof2) = ORC.ModelicaInternal_readLine(f, Int64(2))
      @test line2 == "line two"
      #= endOfFile is only true when reading PAST the last line =#
      @test eof2 == false

      (line3, eof3) = ORC.ModelicaInternal_readLine(f, Int64(3))
      @test line3 == ""
      @test eof3 == true

      ORC.ModelicaStreams_closeFile(f)
      rm(f, force=true)
    end

    @testset "ModelicaInternal_print to file" begin
      local f = tempname()
      ORC.ModelicaInternal_print("hello", f)
      ORC.ModelicaStreams_closeFile(f)
      @test isfile(f)
      @test strip(read(f, String)) == "hello"
      rm(f, force=true)
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

    @testset "ModelicaStrings_substring" begin
      @test ORC.ModelicaStrings_substring("hello world", 1, 5) == "hello"
      @test ORC.ModelicaStrings_substring("hello world", 7, 11) == "world"
      @test ORC.ModelicaStrings_substring("abc", 2, 2) == "b"
    end

    @testset "ModelicaStrings_compare" begin
      #= 1 = Less, 2 = Equal, 3 = Greater (Modelica convention) =#
      @test ORC.ModelicaStrings_compare("abc", "abc", 1) == 2
      @test ORC.ModelicaStrings_compare("abc", "def", 1) == 1
      @test ORC.ModelicaStrings_compare("def", "abc", 1) == 3
      #= Case insensitive =#
      @test ORC.ModelicaStrings_compare("ABC", "abc", 0) == 2
    end

    @testset "ModelicaStrings_scanInteger" begin
      (nextIdx, val) = ORC.ModelicaStrings_scanInteger("42 hello", 1, 0)
      @test val == 42
      @test nextIdx == 3

      (nextIdx2, val2) = ORC.ModelicaStrings_scanInteger("-123abc", 1, 0)
      @test val2 == -123
      @test nextIdx2 == 5
    end

    @testset "ModelicaStrings_scanReal" begin
      (nextIdx, val) = ORC.ModelicaStrings_scanReal("3.14 rest", 1, 0)
      @test isapprox(val, 3.14, atol=1e-10)
      @test nextIdx == 5

      (nextIdx2, val2) = ORC.ModelicaStrings_scanReal("-2.5e3 rest", 1, 0)
      @test isapprox(val2, -2500.0, atol=1e-6)
    end

    @testset "ModelicaStrings_scanIdentifier" begin
      (nextIdx, ident) = ORC.ModelicaStrings_scanIdentifier("myVar = 42", 1)
      @test ident == "myVar"
      @test nextIdx == 6
    end

    @testset "ModelicaStrings_hashString" begin
      #= Same string should produce the same hash =#
      @test ORC.ModelicaStrings_hashString("test") == ORC.ModelicaStrings_hashString("test")
      #= Different strings should (very likely) produce different hashes =#
      @test ORC.ModelicaStrings_hashString("abc") != ORC.ModelicaStrings_hashString("def")
    end
  end

end
