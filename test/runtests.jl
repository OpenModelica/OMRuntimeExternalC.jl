using Test
import OMRuntimeExternalC

function callExternalTable()
  local table::Matrix{Float64} =
         [[1990.0 6.107582727272727]; [1991.0 6.198736363636363]; [1992.0 6.081583636363637]; [1993.0 6.08625818181818]; [1994.0 6.202679999999999];
          [1995.0 6.335061818181818]; [1996.0 6.462572727272727]; [1997.0 6.573962727272727]; [1998.0 6.541412727272727]; [1999.0 6.5226654545454545];
          [2000.0 6.685685454545454]; [2001.0 6.845787272727272]; [2002.0 6.894016363636363]; [2003.0 7.228682727272727]; [2004.0 7.6192745454545445];
          [2005.0 7.895893636363635]; [2006.0 8.102424545454545]; [2007.0 8.228405454545454]; [2008.0 8.342858181818182]; [2009.0 8.468672727272727];
          [2010.0 8.598812727272726]; [2011.0 8.845385454545452]; [2012.0 8.360544607737433]; [2013.0 8.45608126722513]; [2014.0 8.588321153840676];
          [2015.0 8.728730432119024]; [2016.0 8.799230760459748]; [2017.0 8.884731395426048]; [2018.0 8.971411647593571]; [2019.0 9.059503714937884];
          [2020.0 9.146588482570532]; [2021.0 9.230280477125312]; [2022.0 9.166133416303824]; [2023.0 9.200299903494702]; [2024.0 9.237068516886492];
          [2025.0 9.274138430662253]; [2026.0 9.308436638809761]; [2027.0 9.348660422651545]; [2028.0 9.389919823889942]; [2029.0 9.431775987213486];
          [2030.0 9.473836343830683]; [2031.0 9.516475959501381]; [2032.0 9.354884214246265]; [2033.0 9.375028028929197]; [2034.0 9.365094008491594];
          [2035.0 9.339181017160017]; [2036.0 9.29118618837607]; [2037.0 9.235863951913968]; [2038.0 9.18230763493076]; [2039.0 9.156186881587752];
          [2040.0 9.133983057733765]; [2041.0 9.09792656127]; [2042.0 9.046434900013132]; [2043.0 8.962919345475022]; [2044.0 8.954160810512384];
          [2045.0 8.947756963888061]; [2046.0 8.853453387522494]; [2047.0 8.759993810692263]; [2048.0 8.705744292058707]; [2049.0 8.640991233412404];
          [2050.0 8.570889967234864]; [2051.0 8.537449653609043]; [2052.0 8.356076684498683]; [2053.0 8.344462753319181]; [2054.0 8.381434624121633];
          [2055.0 8.365555433090853]; [2056.0 8.35231613552101]; [2057.0 8.357970893778752]; [2058.0 8.351092635828456]; [2059.0 8.325830350745147];
          [2060.0 8.281475871496854]; [2061.0 8.24165876707664]; [2062.0 8.213621942440442]; [2063.0 8.173911445542284]; [2064.0 8.140232070344192];
          [2065.0 8.051026433805529]; [2066.0 7.945747445126002]; [2067.0 7.8351439347482135]; [2068.0 7.913879978410008]; [2069.0 7.897412672332518];
          [2070.0 7.860094305115553]; [2071.0 7.831268865963581]; [2072.0 7.7732244878112855]; [2073.0 7.717391655927772]; [2074.0 7.654239197528638];
          [2075.0 7.588361663644022]; [2076.0 7.490776803843696]; [2077.0 7.4890735556077725]; [2078.0 7.516735739533749]; [2079.0 7.499693818808401];
          [2080.0 7.46723155359057]; [2081.0 7.428675879182364]; [2082.0 7.413377565057651]; [2083.0 7.4069286970626695]; [2084.0 7.309881604797978];
          [2085.0 7.266360041656729]; [2086.0 7.185782061222621]; [2087.0 7.123741480652867]; [2088.0 7.076647069995518]; [2089.0 7.074249247024267];
          [2090.0 7.054770780010477]; [2091.0 7.025785622398915]; [2092.0 6.980720832887263]; [2093.0 6.949145380293533]; [2094.0 6.911361775150058];
          [2095.0 6.92195571691863]; [2096.0 6.905594588709496]; [2097.0 6.877739488375711]; [2098.0 6.842301913644552]; [2099.0 6.767535284314026];
          [2100.0 6.6715324599583505]]
  local columns::Vector{Int64} = [2]
  local smoothness::Int64 = 1
  local extrapolation::Int64 = 2
  local verbose::Int64 = 1
  local fileName::String = "NoName"
  local tableName::String = "NoName"
  #local tableCShape = reduce(vcat, [table[j,i] for i in 1:size(table,2), j in 1:size(table,1)])
  OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_init2(fileName,
                                                               tableName,
                                                               table,
                                                               size(table,1),
                                                               size(table,2),
                                                               columns,
                                                               size(columns,1),
                                                               smoothness,
                                                               extrapolation,
                                                               verbose)
end

@testset "Test the Modelica external C API" begin
  id = callExternalTable()
  @test typeof(id) == Ptr{Nothing}
  @test 0.018230727272727166  == begin
    OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_getDerValue(id, 1, 1.0, 0.2)
  end

  @test 2100.0  == begin
    OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_maximumAbscissa(id)
  end

  @test 1990.0  == begin
    OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_minimumAbscissa(id)
  end

  @test -175.26992290908984  == begin
    OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_getValue(id, 1, 0.2)
  end

  @test 4 == begin
    OMRuntimeExternalC.ModelicaStrings_skipWhiteSpace("   an apple", 1)
  end

  @test 3 == begin
    OMRuntimeExternalC.ModelicaStrings_length("abc")
  end
  @test true == begin
    try
      OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_close(id)
      true
    catch
      false
    end
  end
  #= Test that the API can be called with a vector of vectors as well. =#
  local vec0 = [1.1, 1.2]
  local vec1 = [1.1, 1.2]
  local vecVec::Vector{Vector{Float64}} = [vec0, vec1]
  local columns::Vector{Int64} = [2]
  local smoothness::Int64 = 1
  local extrapolation::Int64 = 2
  local nCols = 1
  local verbose::Bool = true
  local fileName::String = "NoName"
  local tableName::String = "NoName"
  local id2 = OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_init2(fileName,
                                                                           tableName,
                                                                           vecVec,
                                                                           2,
                                                                           2,
                                                                           columns,
                                                                           nCols,
                                                                           smoothness,
                                                                           extrapolation,
                                                                           verbose)
  @test 1.2 == begin
    OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_maximumAbscissa(id2)
  end

  @test 1.1 == begin
    OMRuntimeExternalC.ModelicaStandardTables_CombiTable1D_minimumAbscissa(id2)
  end

end
