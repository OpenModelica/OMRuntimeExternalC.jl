#= Add functions for the Modelica External C API here. =#

#= ---- Safe ccall error handling via ModelicaCallbacks shim ---- =#
#=
  The C shim (libModelicaCallbacks.so) provides:
  - Replacement ModelicaFormatError/ModelicaError that use setjmp/longjmp
    instead of the OMC runtime's uninitialized thread-local jump buffers.
  - safe_* wrapper functions that do setjmp entirely in C, call the target
    function via dlsym, and return 0 on success or nonzero on error.
    Error message is retrieved via modelica_get_error_msg().
  This avoids longjmp across Julia ccall boundaries (which is undefined behavior).
=#

"""
    get_modelica_error()::String

Retrieve the error message from the last failed safe_* call.
"""
function get_modelica_error()::String
  if installedLibPathlibModelicaCallbacks === nothing
    return "ModelicaCallbacks shim not loaded"
  end
  ptr = ccall(
    (:modelica_get_error_msg, installedLibPathlibModelicaCallbacks),
    Cstring, (),
  )
  return ptr == C_NULL ? "" : unsafe_string(ptr)
end

const ExternalCombiTable1D = Ptr{Nothing}

"""
MODELICA_EXPORT void* ModelicaStandardTables_CombiTable1D_init2(
  _In_z_ const char* fileName,
  _In_z_ const char* tableName,
  _In_ double* table,
  size_t nRow,
  size_t nColumn,
  _In_ int* columns,
  size_t nCols,
  int smoothness,
  int extrapolation,
  int verbose) MODELICA_NONNULLATTR;
"""
function ModelicaStandardTables_CombiTable1D_init2(
  fileName::Cstring,
  tableName::Cstring,
  table::Ptr{Cdouble},
  nRow::Csize_t,
  nColumn::Csize_t,
  columns::Ptr{Cint},
  nCols::Csize_t,
  smoothness::Cint,
  extrapolation::Cint,
  verbose::Cint)::Ptr{Cvoid}
end

function ModelicaStandardTables_CombiTable1D_init2(
  fileName::String,
  tableName::String,
  table::Vector{Vector{Float64}},
  nRow::Int64,
  nColumn::Int64,
  columns::Vector{Int64},
  nCols::Int64,
  smoothness::Int64,
  extrapolation::Int64,
  verbose::Integer)
  #= Requires Julia > 1.9 =#
  local tableM = stack(table; dims=1)
  ModelicaStandardTables_CombiTable1D_init2(
    fileName,
    tableName,
    tableM,
    nRow,
    nColumn,
    columns,
    nCols,
    smoothness,
    extrapolation,
    verbose)
end

function ModelicaStandardTables_CombiTable1D_init2(
  fileName::String,
  tableName::String,
  table::Matrix{Float64},
  nRow::Int64,
  nColumn::Int64,
  columns::Vector{Int64},
  nCols::Int64,
  smoothness::Int64,
  extrapolation::Int64,
  verbose::Integer)
  #= Converts the table into the C format, that is double* =#
  local tableCShape = reduce(vcat, [table[j,i] for i in 1:size(table,2), j in 1:size(table,1)])
  local res = ccall((:ModelicaStandardTables_CombiTable1D_init2, installedLibPath), Ptr{Cvoid},
                (Cstring, Cstring, Ptr{Cdouble}, Csize_t, Csize_t, Ptr{Cint}, Csize_t, Cint, Cint, Cint),
                    fileName, tableName, tableCShape, nRow, nColumn, columns, nCols, smoothness, extrapolation, verbose)
  res
end

#=
  // the exernal Modelica function
  function 'Modelica.Blocks.Types.ExternalCombiTable1D.constructor'
    input String 'tableName';
    input String 'fileName';
    input Real[:, :] 'table';
    input Integer[:] 'columns';
    input 'Modelica.Blocks.Types.Smoothness' 'smoothness';
    input 'Modelica.Blocks.Types.Extrapolation' 'extrapolation' = 'Modelica.Blocks.Types.Extrapolation'.LastTwoPoints;
    input Boolean 'verboseRead' = true;
    output 'Modelica.Blocks.Types.ExternalCombiTable1D' 'externalCombiTable1D';
  external "C" 'externalCombiTable1D' = ModelicaStandardTables_CombiTable1D_init2('fileName', 'tableName', 'table', size('table', 1), size('table', 2), 'columns', size('columns', 1), 'smoothness', 'extrapolation', 'verboseRead')annotation(Library={"ModelicaStandardTables","ModelicaIO","ModelicaMatIO","zlib"},LibraryDirectory="modelica://Modelica/Resources/Library");
  /* Externally defined function*/
  end 'Modelica.Blocks.Types.ExternalCombiTable1D.constructor';

  // Modelica code to see how the constructor is called
  type 'Modelica.Blocks.Types.Extrapolation' = enumeration(HoldLastPoint, LastTwoPoints, Periodic, NoExtrapolation);

  type 'Modelica.Blocks.Types.Smoothness' = enumeration(LinearSegments, ContinuousDerivative, ConstantSegments, MonotoneContinuousDerivative1, MonotoneContinuousDerivative2, ModifiedContinuousDerivative);

  parameter String 'combi_CO2_emissions_from_CO2e_CAT.tableName' = "NoName";
  parameter String 'combi_CO2_emissions_from_CO2e_CAT.fileName' = "NoName";
  parameter Boolean 'combi_CO2_emissions_from_CO2e_CAT.verboseRead' = true;
  'Modelica.Blocks.Types.ExternalCombiTable1D'
    'combi_CO2_emissions_from_CO2e_CAT.tableID' =
    'Modelica.Blocks.Types.ExternalCombiTable1D.constructor'(
        if false
        then 'combi_CO2_emissions_from_CO2e_CAT.tableName'
        else "NoName",
        if (false and 'combi_CO2_emissions_from_CO2e_CAT.fileName' <> "NoName") and not 'Modelica.Utilities.Strings.isEmpty'('combi_CO2_emissions_from_CO2e_CAT.fileName')
        then 'combi_CO2_emissions_from_CO2e_CAT.fileName'
        else "NoName",
        {
          {1990.0, 6.107582727272727}, {1991.0, 6.198736363636363}, {1992.0, 6.081583636363637}, {1993.0, 6.08625818181818}, {1994.0, 6.202679999999999},
          {1995.0, 6.335061818181818}, {1996.0, 6.462572727272727}, {1997.0, 6.573962727272727}, {1998.0, 6.541412727272727}, {1999.0, 6.5226654545454545},
          {2000.0, 6.685685454545454}, {2001.0, 6.845787272727272}, {2002.0, 6.894016363636363}, {2003.0, 7.228682727272727}, {2004.0, 7.6192745454545445},
          {2005.0, 7.895893636363635}, {2006.0, 8.102424545454545}, {2007.0, 8.228405454545454}, {2008.0, 8.342858181818182}, {2009.0, 8.468672727272727},
          {2010.0, 8.598812727272726}, {2011.0, 8.845385454545452}, {2012.0, 8.360544607737433}, {2013.0, 8.45608126722513}, {2014.0, 8.588321153840676},
          {2015.0, 8.728730432119024}, {2016.0, 8.799230760459748}, {2017.0, 8.884731395426048}, {2018.0, 8.971411647593571}, {2019.0, 9.059503714937884},
          {2020.0, 9.146588482570532}, {2021.0, 9.230280477125312}, {2022.0, 9.166133416303824}, {2023.0, 9.200299903494702}, {2024.0, 9.237068516886492},
          {2025.0, 9.274138430662253}, {2026.0, 9.308436638809761}, {2027.0, 9.348660422651545}, {2028.0, 9.389919823889942}, {2029.0, 9.431775987213486},
          {2030.0, 9.473836343830683}, {2031.0, 9.516475959501381}, {2032.0, 9.354884214246265}, {2033.0, 9.375028028929197}, {2034.0, 9.365094008491594},
          {2035.0, 9.339181017160017}, {2036.0, 9.29118618837607}, {2037.0, 9.235863951913968}, {2038.0, 9.18230763493076}, {2039.0, 9.156186881587752},
          {2040.0, 9.133983057733765}, {2041.0, 9.09792656127}, {2042.0, 9.046434900013132}, {2043.0, 8.962919345475022}, {2044.0, 8.954160810512384},
          {2045.0, 8.947756963888061}, {2046.0, 8.853453387522494}, {2047.0, 8.759993810692263}, {2048.0, 8.705744292058707}, {2049.0, 8.640991233412404},
          {2050.0, 8.570889967234864}, {2051.0, 8.537449653609043}, {2052.0, 8.356076684498683}, {2053.0, 8.344462753319181}, {2054.0, 8.381434624121633},
          {2055.0, 8.365555433090853}, {2056.0, 8.35231613552101}, {2057.0, 8.357970893778752}, {2058.0, 8.351092635828456}, {2059.0, 8.325830350745147},
          {2060.0, 8.281475871496854}, {2061.0, 8.24165876707664}, {2062.0, 8.213621942440442}, {2063.0, 8.173911445542284}, {2064.0, 8.140232070344192},
          {2065.0, 8.051026433805529}, {2066.0, 7.945747445126002}, {2067.0, 7.8351439347482135}, {2068.0, 7.913879978410008}, {2069.0, 7.897412672332518},
          {2070.0, 7.860094305115553}, {2071.0, 7.831268865963581}, {2072.0, 7.7732244878112855}, {2073.0, 7.717391655927772}, {2074.0, 7.654239197528638},
          {2075.0, 7.588361663644022}, {2076.0, 7.490776803843696}, {2077.0, 7.4890735556077725}, {2078.0, 7.516735739533749}, {2079.0, 7.499693818808401},
          {2080.0, 7.46723155359057}, {2081.0, 7.428675879182364}, {2082.0, 7.413377565057651}, {2083.0, 7.4069286970626695}, {2084.0, 7.309881604797978},
          {2085.0, 7.266360041656729}, {2086.0, 7.185782061222621}, {2087.0, 7.123741480652867}, {2088.0, 7.076647069995518}, {2089.0, 7.074249247024267},
          {2090.0, 7.054770780010477}, {2091.0, 7.025785622398915}, {2092.0, 6.980720832887263}, {2093.0, 6.949145380293533}, {2094.0, 6.911361775150058},
          {2095.0, 6.92195571691863}, {2096.0, 6.905594588709496}, {2097.0, 6.877739488375711}, {2098.0, 6.842301913644552}, {2099.0, 6.767535284314026},
          {2100.0, 6.6715324599583505}
        },
        {2},
        'Modelica.Blocks.Types.Smoothness'.LinearSegments,
        'Modelica.Blocks.Types.Extrapolation'.LastTwoPoints,
        if false
        then 'combi_CO2_emissions_from_CO2e_CAT.verboseRead'
        else false);
=#

"""
Desctructor:
void ModelicaStandardTables_CombiTable1D_close(void* _tableID)
"""
function ModelicaStandardTables_CombiTable1D_close(_tableID::Ptr)
end

function ModelicaStandardTables_CombiTable1D_close(tableID::ExternalCombiTable1D)
  res = ccall(
    (:ModelicaStandardTables_CombiTable1D_close, installedLibPath),
    Cvoid #= Returns =#,
    (Ptr{Cvoid},),
    tableID,)
end

"""
Externally defined as:
MODELICA_EXPORT double ModelicaStandardTables_CombiTable1D_getDerValue(void* tableID, int icol,
                                                                       double u, double der_u);
"""
function ModelicaStandardTables_CombiTable1D_getDerValue(
  tableID::Ptr{Cvoid},
  icol::Cint,
  u::Cdouble,
  der_u::Cdouble,
  )::Cdouble
end

"""
ModelicaStandardTables_CombiTable1D_getDerValue(
  tableID::ExternalCombiTable1D,
  icol::Int64,
  u::Float64,
  der_u::Float64,
  )
"""
function ModelicaStandardTables_CombiTable1D_getDerValue(
  tableID::ExternalCombiTable1D,
  icol::Int64,
  u::Float64,
  der_u::Float64,
  )
  local res = 0
  try
    res = ccall((:ModelicaStandardTables_CombiTable1D_getDerValue, installedLibPath),
                Cdouble #= Returns =#,
                (Ptr{Cvoid}, Cint, Cdouble, Cdouble),
                tableID, icol, u, der_u)
  catch e
    @error "Calling ModelicaStandardTables_CombiTable1D_getDerValue. Check that icol is within the bounds of the table" icol
  end
  return res
end

"""
  double ModelicaStandardTables_CombiTable1D_getValue(void* _tableID, int iCol, double u)
"""
function ModelicaStandardTables_CombiTable1D_getValue(
  tableID::Ptr{Cvoid},
  icol::Cint,
  u::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTable1D_getValue(
  tableID::ExternalCombiTable1D,
  icol::Int64,
  u::Float64,
  )::Float64
  res = ccall((:ModelicaStandardTables_CombiTable1D_getValue, installedLibPath),
              Cdouble #= Returns =#,
              (Ptr{Cvoid}, Cint, Cdouble),
              tableID, icol, u)
end

"""
  double ModelicaStandardTables_CombiTable1D_maximumAbscissa(void* _tableID)
"""
function ModelicaStandardTables_CombiTable1D_maximumAbscissa(arg::Ptr)
end

"""
  ModelicaStandardTables_CombiTable1D_maximumAbscissa(tableID::ExternalCombiTable1D)::Float64
"""
function ModelicaStandardTables_CombiTable1D_maximumAbscissa(tableID::ExternalCombiTable1D)::Float64
  res = ccall((:ModelicaStandardTables_CombiTable1D_maximumAbscissa, installedLibPath),
              #= Returns =# Cdouble,
              (Ptr{Cvoid},),
              tableID)
  return res
end

"""
double ModelicaStandardTables_CombiTable1D_minimumAbscissa(void* _tableID)
"""
function ModelicaStandardTables_CombiTable1D_minimumAbscissa(arg::Ptr)
end

"""
  ModelicaStandardTables_CombiTable1D_minimumAbscissa(tableID::ExternalCombiTable1D)
"""
function ModelicaStandardTables_CombiTable1D_minimumAbscissa(tableID::ExternalCombiTable1D)
    res = ccall((:ModelicaStandardTables_CombiTable1D_minimumAbscissa, installedLibPath),
              #= Returns =# Cdouble,
              (Ptr{Cvoid},),
                tableID)
end


"""
int ModelicaStrings_skipWhiteSpace(_In_z_ const char* string, int i)
  Returns index of the string after whitespace have been skipped.
"""
function ModelicaStrings_skipWhiteSpace(string::Ptr{Cchar}, startIndex::Cint)
end

"""
ModelicaStrings_skipWhiteSpace(string::String, startIndex::Int64)
"""
function ModelicaStrings_skipWhiteSpace(string::String, startIndex::Int64)
  res = ccall((:ModelicaStrings_skipWhiteSpace, installedLibPathlibModelicaExternalC),
              #= Returns =# Cint,
              (Cstring, Cint),
              string, startIndex)
  return res
end

"""
ModelicaStrings_length(_In_z_ const char* string)
"""
function ModelicaStrings_length(string::Ptr{Cchar})
end

"""
ModelicaStrings_length(string::String)
"""
function ModelicaStrings_length(string::String)
    res = ccall((:ModelicaStrings_length, installedLibPathlibModelicaExternalC),
              #= Returns =# Cint,
              (Cstring,),
              string)
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTable1D_getDer2Value(void* tableID, int icol,
                                                                        double u, double der_u, double der2_u);
"""
function ModelicaStandardTables_CombiTable1D_getDer2Value(
  tableID::Ptr{Cvoid},
  icol::Cint,
  u::Cdouble,
  der_u::Cdouble,
  der2_u::Cdouble,
  )::Cdouble
end

"""
ModelicaStandardTables_CombiTable1D_getDer2Value(
  tableID::ExternalCombiTable1D,
  icol::Int64,
  u::Float64,
  der_u::Float64,
  der2_u::Float64,
  )
"""
function ModelicaStandardTables_CombiTable1D_getDer2Value(
  tableID::ExternalCombiTable1D,
  icol::Int64,
  u::Float64,
  der_u::Float64,
  der2_u::Float64,
  )
  local res = 0.0
  try
    res = ccall((:ModelicaStandardTables_CombiTable1D_getDer2Value, installedLibPath),
                Cdouble #= Returns =#,
                (Ptr{Cvoid}, Cint, Cdouble, Cdouble, Cdouble),
                tableID, icol, u, der_u, der2_u)
  catch e
    @error "Calling ModelicaStandardTables_CombiTable1D_getDer2Value. Check that icol is within the bounds of the table" icol
  end
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTable1D_read(void* tableID, int force, int verbose);
"""
function ModelicaStandardTables_CombiTable1D_read(tableID::Ptr{Cvoid}, force::Cint, verbose::Cint)::Cdouble
end

"""
ModelicaStandardTables_CombiTable1D_read(tableID::ExternalCombiTable1D, force::Int64, verbose::Int64)
"""
function ModelicaStandardTables_CombiTable1D_read(tableID::ExternalCombiTable1D, force::Int64, verbose::Int64)
  res = ccall((:ModelicaStandardTables_CombiTable1D_read, installedLibPath),
              Cdouble #= Returns =#,
              (Ptr{Cvoid}, Cint, Cint),
              tableID, force, verbose)
  return res
end

#= ================================================================ =#
#=  CombiTimeTable                                                  =#
#= ================================================================ =#

const ExternalCombiTimeTable = Ptr{Nothing}

"""
MODELICA_EXPORT void* ModelicaStandardTables_CombiTimeTable_init2(
  _In_z_ const char* fileName,
  _In_z_ const char* tableName,
  _In_ double* table,
  size_t nRow,
  size_t nColumn,
  double startTime,
  _In_ int* columns,
  size_t nCols,
  int smoothness,
  int extrapolation,
  double shiftTime,
  int timeEvents,
  int verbose) MODELICA_NONNULLATTR;
"""
function ModelicaStandardTables_CombiTimeTable_init2(
  fileName::Cstring,
  tableName::Cstring,
  table::Ptr{Cdouble},
  nRow::Csize_t,
  nColumn::Csize_t,
  startTime::Cdouble,
  columns::Ptr{Cint},
  nCols::Csize_t,
  smoothness::Cint,
  extrapolation::Cint,
  shiftTime::Cdouble,
  timeEvents::Cint,
  verbose::Cint)::Ptr{Cvoid}
end

function ModelicaStandardTables_CombiTimeTable_init2(
  fileName::String,
  tableName::String,
  table::Vector{Vector{Float64}},
  nRow::Int64,
  nColumn::Int64,
  startTime::Float64,
  columns::Vector{Int64},
  nCols::Int64,
  smoothness::Int64,
  extrapolation::Int64,
  shiftTime::Float64,
  timeEvents::Int64,
  verbose::Integer)
  #= Requires Julia > 1.9 =#
  local tableM = stack(table; dims=1)
  ModelicaStandardTables_CombiTimeTable_init2(
    fileName, tableName, tableM,
    nRow, nColumn, startTime,
    columns, nCols,
    smoothness, extrapolation, shiftTime, timeEvents, verbose)
end

function ModelicaStandardTables_CombiTimeTable_init2(
  fileName::String,
  tableName::String,
  table::Matrix{Float64},
  nRow::Int64,
  nColumn::Int64,
  startTime::Float64,
  columns::Vector{Int64},
  nCols::Int64,
  smoothness::Int64,
  extrapolation::Int64,
  shiftTime::Float64,
  timeEvents::Int64,
  verbose::Integer)
  #= Converts the table into the C format, that is double* =#
  local tableCShape = reduce(vcat, [table[j,i] for i in 1:size(table,2), j in 1:size(table,1)])
  local res = ccall((:ModelicaStandardTables_CombiTimeTable_init2, installedLibPath), Ptr{Cvoid},
                (Cstring, Cstring, Ptr{Cdouble}, Csize_t, Csize_t, Cdouble, Ptr{Cint}, Csize_t, Cint, Cint, Cdouble, Cint, Cint),
                    fileName, tableName, tableCShape, nRow, nColumn, startTime, columns, nCols, smoothness, extrapolation, shiftTime, timeEvents, verbose)
  res
end

"""
void ModelicaStandardTables_CombiTimeTable_close(void* tableID)
"""
function ModelicaStandardTables_CombiTimeTable_close(_tableID::Ptr)
end

function ModelicaStandardTables_CombiTimeTable_close(tableID::ExternalCombiTimeTable)
  ccall(
    (:ModelicaStandardTables_CombiTimeTable_close, installedLibPath),
    Cvoid #= Returns =#,
    (Ptr{Cvoid},),
    tableID)
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_getValue(void* tableID, int icol,
                                                                      double t, double nextTimeEvent, double preNextTimeEvent);
"""
function ModelicaStandardTables_CombiTimeTable_getValue(
  tableID::Ptr{Cvoid},
  icol::Cint,
  t::Cdouble,
  nextTimeEvent::Cdouble,
  preNextTimeEvent::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTimeTable_getValue(
  tableID::ExternalCombiTimeTable,
  icol::Int64,
  t::Float64,
  nextTimeEvent::Float64,
  preNextTimeEvent::Float64,
  )::Float64
  res = ccall((:ModelicaStandardTables_CombiTimeTable_getValue, installedLibPath),
              Cdouble #= Returns =#,
              (Ptr{Cvoid}, Cint, Cdouble, Cdouble, Cdouble),
              tableID, icol, t, nextTimeEvent, preNextTimeEvent)
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_getDerValue(void* tableID, int icol,
                                                                         double t, double nextTimeEvent, double preNextTimeEvent, double der_t);
"""
function ModelicaStandardTables_CombiTimeTable_getDerValue(
  tableID::Ptr{Cvoid},
  icol::Cint,
  t::Cdouble,
  nextTimeEvent::Cdouble,
  preNextTimeEvent::Cdouble,
  der_t::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTimeTable_getDerValue(
  tableID::ExternalCombiTimeTable,
  icol::Int64,
  t::Float64,
  nextTimeEvent::Float64,
  preNextTimeEvent::Float64,
  der_t::Float64,
  )
  local res = 0.0
  try
    res = ccall((:ModelicaStandardTables_CombiTimeTable_getDerValue, installedLibPath),
                Cdouble #= Returns =#,
                (Ptr{Cvoid}, Cint, Cdouble, Cdouble, Cdouble, Cdouble),
                tableID, icol, t, nextTimeEvent, preNextTimeEvent, der_t)
  catch e
    @error "Calling ModelicaStandardTables_CombiTimeTable_getDerValue. Check that icol is within the bounds of the table" icol
  end
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_getDer2Value(void* tableID, int icol,
                                                                          double t, double nextTimeEvent, double preNextTimeEvent,
                                                                          double der_t, double der2_t);
"""
function ModelicaStandardTables_CombiTimeTable_getDer2Value(
  tableID::Ptr{Cvoid},
  icol::Cint,
  t::Cdouble,
  nextTimeEvent::Cdouble,
  preNextTimeEvent::Cdouble,
  der_t::Cdouble,
  der2_t::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTimeTable_getDer2Value(
  tableID::ExternalCombiTimeTable,
  icol::Int64,
  t::Float64,
  nextTimeEvent::Float64,
  preNextTimeEvent::Float64,
  der_t::Float64,
  der2_t::Float64,
  )
  local res = 0.0
  try
    res = ccall((:ModelicaStandardTables_CombiTimeTable_getDer2Value, installedLibPath),
                Cdouble #= Returns =#,
                (Ptr{Cvoid}, Cint, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble),
                tableID, icol, t, nextTimeEvent, preNextTimeEvent, der_t, der2_t)
  catch e
    @error "Calling ModelicaStandardTables_CombiTimeTable_getDer2Value. Check that icol is within the bounds of the table" icol
  end
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_minimumTime(void* tableID);
"""
function ModelicaStandardTables_CombiTimeTable_minimumTime(arg::Ptr)
end

function ModelicaStandardTables_CombiTimeTable_minimumTime(tableID::ExternalCombiTimeTable)::Float64
  res = ccall((:ModelicaStandardTables_CombiTimeTable_minimumTime, installedLibPath),
              #= Returns =# Cdouble,
              (Ptr{Cvoid},),
              tableID)
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_maximumTime(void* tableID);
"""
function ModelicaStandardTables_CombiTimeTable_maximumTime(arg::Ptr)
end

function ModelicaStandardTables_CombiTimeTable_maximumTime(tableID::ExternalCombiTimeTable)::Float64
  res = ccall((:ModelicaStandardTables_CombiTimeTable_maximumTime, installedLibPath),
              #= Returns =# Cdouble,
              (Ptr{Cvoid},),
              tableID)
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_nextTimeEvent(void* tableID, double t);
"""
function ModelicaStandardTables_CombiTimeTable_nextTimeEvent(arg::Ptr, t::Cdouble)::Cdouble
end

function ModelicaStandardTables_CombiTimeTable_nextTimeEvent(tableID::ExternalCombiTimeTable, t::Float64)::Float64
  res = ccall((:ModelicaStandardTables_CombiTimeTable_nextTimeEvent, installedLibPath),
              #= Returns =# Cdouble,
              (Ptr{Cvoid}, Cdouble),
              tableID, t)
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTimeTable_read(void* tableID, int force, int verbose);
"""
function ModelicaStandardTables_CombiTimeTable_read(tableID::Ptr{Cvoid}, force::Cint, verbose::Cint)::Cdouble
end

function ModelicaStandardTables_CombiTimeTable_read(tableID::ExternalCombiTimeTable, force::Int64, verbose::Int64)
  res = ccall((:ModelicaStandardTables_CombiTimeTable_read, installedLibPath),
              Cdouble #= Returns =#,
              (Ptr{Cvoid}, Cint, Cint),
              tableID, force, verbose)
  return res
end

#= ================================================================ =#
#=  CombiTable2D                                                    =#
#= ================================================================ =#

const ExternalCombiTable2D = Ptr{Nothing}

"""
MODELICA_EXPORT void* ModelicaStandardTables_CombiTable2D_init2(
  _In_z_ const char* fileName,
  _In_z_ const char* tableName,
  _In_ double* table,
  size_t nRow,
  size_t nColumn,
  int smoothness,
  int extrapolation,
  int verbose) MODELICA_NONNULLATTR;
"""
function ModelicaStandardTables_CombiTable2D_init2(
  fileName::Cstring,
  tableName::Cstring,
  table::Ptr{Cdouble},
  nRow::Csize_t,
  nColumn::Csize_t,
  smoothness::Cint,
  extrapolation::Cint,
  verbose::Cint)::Ptr{Cvoid}
end

function ModelicaStandardTables_CombiTable2D_init2(
  fileName::String,
  tableName::String,
  table::Vector{Vector{Float64}},
  nRow::Int64,
  nColumn::Int64,
  smoothness::Int64,
  extrapolation::Int64,
  verbose::Integer)
  #= Requires Julia > 1.9 =#
  local tableM = stack(table; dims=1)
  ModelicaStandardTables_CombiTable2D_init2(
    fileName, tableName, tableM,
    nRow, nColumn,
    smoothness, extrapolation, verbose)
end

function ModelicaStandardTables_CombiTable2D_init2(
  fileName::String,
  tableName::String,
  table::Matrix{Float64},
  nRow::Int64,
  nColumn::Int64,
  smoothness::Int64,
  extrapolation::Int64,
  verbose::Integer)
  #= Converts the table into the C format, that is double* =#
  local tableCShape = reduce(vcat, [table[j,i] for i in 1:size(table,2), j in 1:size(table,1)])
  local res = ccall((:ModelicaStandardTables_CombiTable2D_init2, installedLibPath), Ptr{Cvoid},
                (Cstring, Cstring, Ptr{Cdouble}, Csize_t, Csize_t, Cint, Cint, Cint),
                    fileName, tableName, tableCShape, nRow, nColumn, smoothness, extrapolation, verbose)
  res
end

"""
void ModelicaStandardTables_CombiTable2D_close(void* tableID)
"""
function ModelicaStandardTables_CombiTable2D_close(_tableID::Ptr)
end

function ModelicaStandardTables_CombiTable2D_close(tableID::ExternalCombiTable2D)
  ccall(
    (:ModelicaStandardTables_CombiTable2D_close, installedLibPath),
    Cvoid #= Returns =#,
    (Ptr{Cvoid},),
    tableID)
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTable2D_getValue(void* tableID, double u1, double u2);
"""
function ModelicaStandardTables_CombiTable2D_getValue(
  arg::Ptr,
  u1::Cdouble,
  u2::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTable2D_getValue(
  tableID::ExternalCombiTable2D,
  u1::Float64,
  u2::Float64,
  )::Float64
  res = ccall((:ModelicaStandardTables_CombiTable2D_getValue, installedLibPath),
              Cdouble #= Returns =#,
              (Ptr{Cvoid}, Cdouble, Cdouble),
              tableID, u1, u2)
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTable2D_getDerValue(void* tableID,
                                                                       double u1, double u2, double der_u1, double der_u2);
"""
function ModelicaStandardTables_CombiTable2D_getDerValue(
  arg::Ptr,
  u1::Cdouble,
  u2::Cdouble,
  der_u1::Cdouble,
  der_u2::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTable2D_getDerValue(
  tableID::ExternalCombiTable2D,
  u1::Float64,
  u2::Float64,
  der_u1::Float64,
  der_u2::Float64,
  )
  local res = 0.0
  try
    res = ccall((:ModelicaStandardTables_CombiTable2D_getDerValue, installedLibPath),
                Cdouble #= Returns =#,
                (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble),
                tableID, u1, u2, der_u1, der_u2)
  catch e
    @error "Calling ModelicaStandardTables_CombiTable2D_getDerValue" u1 u2
  end
  return res
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTable2D_getDer2Value(void* tableID,
                                                                        double u1, double u2, double der_u1, double der_u2,
                                                                        double der2_u1, double der2_u2);
"""
function ModelicaStandardTables_CombiTable2D_getDer2Value(
  arg::Ptr,
  u1::Cdouble,
  u2::Cdouble,
  der_u1::Cdouble,
  der_u2::Cdouble,
  der2_u1::Cdouble,
  der2_u2::Cdouble,
  )::Cdouble
end

function ModelicaStandardTables_CombiTable2D_getDer2Value(
  tableID::ExternalCombiTable2D,
  u1::Float64,
  u2::Float64,
  der_u1::Float64,
  der_u2::Float64,
  der2_u1::Float64,
  der2_u2::Float64,
  )
  local res = 0.0
  try
    res = ccall((:ModelicaStandardTables_CombiTable2D_getDer2Value, installedLibPath),
                Cdouble #= Returns =#,
                (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble, Cdouble),
                tableID, u1, u2, der_u1, der_u2, der2_u1, der2_u2)
  catch e
    @error "Calling ModelicaStandardTables_CombiTable2D_getDer2Value" u1 u2
  end
  return res
end

"""
MODELICA_EXPORT void ModelicaStandardTables_CombiTable2D_minimumAbscissa(void* tableID, double* uMin);
  Writes two doubles to uMin: uMin[0] = min of u1 axis, uMin[1] = min of u2 axis.
"""
function ModelicaStandardTables_CombiTable2D_minimumAbscissa(arg::Ptr)
end

function ModelicaStandardTables_CombiTable2D_minimumAbscissa(tableID::ExternalCombiTable2D)
  uMin = zeros(Cdouble, 2)
  ccall((:ModelicaStandardTables_CombiTable2D_minimumAbscissa, installedLibPath),
        Cvoid #= Returns =#,
        (Ptr{Cvoid}, Ptr{Cdouble}),
        tableID, uMin)
  return (uMin[1], uMin[2])
end

"""
MODELICA_EXPORT void ModelicaStandardTables_CombiTable2D_maximumAbscissa(void* tableID, double* uMax);
  Writes two doubles to uMax: uMax[0] = max of u1 axis, uMax[1] = max of u2 axis.
"""
function ModelicaStandardTables_CombiTable2D_maximumAbscissa(arg::Ptr)
end

function ModelicaStandardTables_CombiTable2D_maximumAbscissa(tableID::ExternalCombiTable2D)
  uMax = zeros(Cdouble, 2)
  ccall((:ModelicaStandardTables_CombiTable2D_maximumAbscissa, installedLibPath),
        Cvoid #= Returns =#,
        (Ptr{Cvoid}, Ptr{Cdouble}),
        tableID, uMax)
  return (uMax[1], uMax[2])
end

"""
MODELICA_EXPORT double ModelicaStandardTables_CombiTable2D_read(void* tableID, int force, int verbose);
"""
function ModelicaStandardTables_CombiTable2D_read(tableID::Ptr{Cvoid}, force::Cint, verbose::Cint)::Cdouble
end

function ModelicaStandardTables_CombiTable2D_read(tableID::ExternalCombiTable2D, force::Int64, verbose::Int64)
  res = ccall((:ModelicaStandardTables_CombiTable2D_read, installedLibPath),
              Cdouble #= Returns =#,
              (Ptr{Cvoid}, Cint, Cint),
              tableID, force, verbose)
  return res
end

#= ================================================================ =#
#=  ModelicaStrings - Additional functions                          =#
#= ================================================================ =#

"""
MODELICA_EXPORT const char* ModelicaStrings_substring(_In_z_ const char* string, int startIndex, int endIndex);
"""
function ModelicaStrings_substring(string::Ptr{Cchar}, startIndex::Cint, endIndex::Cint)
end

"""
ModelicaStrings_substring(string::String, startIndex::Int64, endIndex::Int64)
  Returns the substring from startIndex to endIndex (1-based, inclusive).
"""
function ModelicaStrings_substring(string::String, startIndex::Int64, endIndex::Int64)
  res = ccall((:ModelicaStrings_substring, installedLibPathlibModelicaExternalC),
              #= Returns =# Cstring,
              (Cstring, Cint, Cint),
              string, startIndex, endIndex)
  return unsafe_string(res)
end

"""
MODELICA_EXPORT int ModelicaStrings_compare(_In_z_ const char* string1, _In_z_ const char* string2, int caseSensitive);
"""
function ModelicaStrings_compare(string1::Ptr{Cchar}, string2::Ptr{Cchar}, caseSensitive::Cint)
end

"""
ModelicaStrings_compare(string1::String, string2::String, caseSensitive::Int64)
  Compares two strings. Returns 1 if string1 < string2, 2 if equal, 3 if string1 > string2.
"""
function ModelicaStrings_compare(string1::String, string2::String, caseSensitive::Int64)
  res = ccall((:ModelicaStrings_compare, installedLibPathlibModelicaExternalC),
              #= Returns =# Cint,
              (Cstring, Cstring, Cint),
              string1, string2, caseSensitive)
  return Int64(res)
end

"""
MODELICA_EXPORT void ModelicaStrings_scanIdentifier(_In_z_ const char* string, int startIndex,
                                                     int* nextIndex, const char** identifier);
"""
function ModelicaStrings_scanIdentifier(string::Ptr{Cchar}, startIndex::Cint)
end

"""
ModelicaStrings_scanIdentifier(string::String, startIndex::Int64)
  Scans for an identifier starting at startIndex.
  Returns (nextIndex, identifier).
"""
function ModelicaStrings_scanIdentifier(string::String, startIndex::Int64)
  nextIndex = Ref{Cint}(0)
  identifier = Ref{Cstring}(C_NULL)
  ccall((:ModelicaStrings_scanIdentifier, installedLibPathlibModelicaExternalC),
        Cvoid,
        (Cstring, Cint, Ref{Cint}, Ref{Cstring}),
        string, startIndex, nextIndex, identifier)
  local idStr = identifier[] == C_NULL ? "" : unsafe_string(identifier[])
  return (Int64(nextIndex[]), idStr)
end

"""
MODELICA_EXPORT void ModelicaStrings_scanInteger(_In_z_ const char* string, int startIndex,
                                                  int unsignedNumber, int* nextIndex, int* integerNumber);
"""
function ModelicaStrings_scanInteger(string::Ptr{Cchar}, startIndex::Cint, unsignedNumber::Cint)
end

"""
ModelicaStrings_scanInteger(string::String, startIndex::Int64, unsignedNumber::Int64)
  Scans for an integer starting at startIndex.
  If unsignedNumber != 0, only unsigned integers are recognized.
  Returns (nextIndex, integerNumber).
"""
function ModelicaStrings_scanInteger(string::String, startIndex::Int64, unsignedNumber::Int64)
  nextIndex = Ref{Cint}(0)
  integerNumber = Ref{Cint}(0)
  ccall((:ModelicaStrings_scanInteger, installedLibPathlibModelicaExternalC),
        Cvoid,
        (Cstring, Cint, Cint, Ref{Cint}, Ref{Cint}),
        string, startIndex, unsignedNumber, nextIndex, integerNumber)
  return (Int64(nextIndex[]), Int64(integerNumber[]))
end

"""
MODELICA_EXPORT void ModelicaStrings_scanReal(_In_z_ const char* string, int startIndex,
                                               int unsignedNumber, int* nextIndex, double* number);
"""
function ModelicaStrings_scanReal(string::Ptr{Cchar}, startIndex::Cint, unsignedNumber::Cint)
end

"""
ModelicaStrings_scanReal(string::String, startIndex::Int64, unsignedNumber::Int64)
  Scans for a real number starting at startIndex.
  If unsignedNumber != 0, only unsigned numbers are recognized.
  Returns (nextIndex, number).
"""
function ModelicaStrings_scanReal(string::String, startIndex::Int64, unsignedNumber::Int64)
  nextIndex = Ref{Cint}(0)
  number = Ref{Cdouble}(0.0)
  ccall((:ModelicaStrings_scanReal, installedLibPathlibModelicaExternalC),
        Cvoid,
        (Cstring, Cint, Cint, Ref{Cint}, Ref{Cdouble}),
        string, startIndex, unsignedNumber, nextIndex, number)
  return (Int64(nextIndex[]), Float64(number[]))
end

"""
MODELICA_EXPORT void ModelicaStrings_scanString(_In_z_ const char* string, int startIndex,
                                                 int* nextIndex, const char** result);
"""
function ModelicaStrings_scanString(string::Ptr{Cchar}, startIndex::Cint)
end

"""
ModelicaStrings_scanString(string::String, startIndex::Int64)
  Scans for a quoted string starting at startIndex.
  Returns (nextIndex, result).
"""
function ModelicaStrings_scanString(string::String, startIndex::Int64)
  nextIndex = Ref{Cint}(0)
  result = Ref{Cstring}(C_NULL)
  ccall((:ModelicaStrings_scanString, installedLibPathlibModelicaExternalC),
        Cvoid,
        (Cstring, Cint, Ref{Cint}, Ref{Cstring}),
        string, startIndex, nextIndex, result)
  local resStr = result[] == C_NULL ? "" : unsafe_string(result[])
  return (Int64(nextIndex[]), resStr)
end

"""
MODELICA_EXPORT int ModelicaStrings_hashString(_In_z_ const char* str);
"""
function ModelicaStrings_hashString(string::Ptr{Cchar})
end

"""
ModelicaStrings_hashString(string::String)
  Returns a hash value for the given string.
"""
function ModelicaStrings_hashString(string::String)
  res = ccall((:ModelicaStrings_hashString, installedLibPathlibModelicaExternalC),
              #= Returns =# Cint,
              (Cstring,),
              string)
  return Int64(res)
end

#= ---- ModelicaIO functions (via safe_* wrappers in libModelicaCallbacks) ---- =#

"""
    ModelicaIO_readMatrixSizes(fileName, matrixName) -> Vector{Int64}

Read the dimensions [nrow, ncol] of a matrix stored in a MATLAB MAT file.
"""
function ModelicaIO_readMatrixSizes(fileName::String, matrixName::String)::Vector{Int64}
  dim = zeros(Cint, 2)
  rc = ccall(
    (:safe_ModelicaIO_readMatrixSizes, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Cstring, Ptr{Cint}),
    fileName, matrixName, dim,
  )
  rc != 0 && error("ModelicaIO_readMatrixSizes failed: ", get_modelica_error())
  return Int64[dim[1], dim[2]]
end

"""
    ModelicaIO_readRealMatrix(fileName, matrixName, nrow, ncol, verbose) -> Matrix{Float64}

Read a real matrix of size nrow x ncol from a MATLAB MAT file.
"""
function ModelicaIO_readRealMatrix(
  fileName::String,
  matrixName::String,
  nrow::Int64,
  ncol::Int64,
  verbose::Bool = true,
)::Matrix{Float64}
  buffer = zeros(Cdouble, nrow * ncol)
  rc = ccall(
    (:safe_ModelicaIO_readRealMatrix, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Cstring, Ptr{Cdouble}, Csize_t, Csize_t, Cint),
    fileName, matrixName, buffer, Csize_t(nrow), Csize_t(ncol), Cint(verbose),
  )
  rc != 0 && error("ModelicaIO_readRealMatrix failed: ", get_modelica_error())
  #= C fills row-major; reshape as (ncol, nrow) then transpose for Julia column-major =#
  return Matrix{Float64}(reshape(buffer, ncol, nrow)')
end

"""
    ModelicaIO_writeRealMatrix(fileName, matrixName, matrix; append, version)

Write a real matrix to a MATLAB MAT file.
"""
function ModelicaIO_writeRealMatrix(
  fileName::String,
  matrixName::String,
  matrix::Matrix{Float64},
  append::Bool = false,
  version::String = "4",
)::Int64
  local nrow = size(matrix, 1)
  local ncol = size(matrix, 2)
  #= Convert Julia column-major to C row-major: transpose then flatten =#
  local buffer = vec(Matrix{Float64}(matrix'))
  rc = ccall(
    (:safe_ModelicaIO_writeRealMatrix, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Cstring, Ptr{Cdouble}, Csize_t, Csize_t, Cint, Cstring),
    fileName, matrixName, buffer, Csize_t(nrow), Csize_t(ncol), Cint(append), version,
  )
  rc == -1 && error("ModelicaIO_writeRealMatrix failed: ", get_modelica_error())
  return Int64(rc)
end

#= ---- ModelicaInternal functions (via safe_* wrappers in libModelicaCallbacks) ---- =#

"""
    ModelicaInternal_print(string, fileName)

Print a string to a file (append mode) or to stdout if fileName is empty.
"""
function ModelicaInternal_print(string::String, fileName::String)
  rc = ccall(
    (:safe_ModelicaInternal_print, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Cstring),
    string, fileName,
  )
  rc != 0 && error("ModelicaInternal_print failed: ", get_modelica_error())
  return nothing
end

"""
    ModelicaInternal_readLine(fileName, lineNumber) -> (String, Bool)

Read a specific line from a file. Returns (line_content, endOfFile).
"""
function ModelicaInternal_readLine(fileName::String, lineNumber::Int64)
  bufPtr = Ref{Cstring}(C_NULL)
  endOfFile = Ref{Cint}(0)
  rc = ccall(
    (:safe_ModelicaInternal_readLine, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Cint, Ref{Cstring}, Ref{Cint}),
    fileName, Cint(lineNumber), bufPtr, endOfFile,
  )
  rc != 0 && error("ModelicaInternal_readLine failed: ", get_modelica_error())
  local str = bufPtr[] == C_NULL ? "" : unsafe_string(bufPtr[])
  return (str, endOfFile[] != 0)
end

"""
    ModelicaInternal_countLines(fileName) -> Int64

Count the number of lines in a file.
"""
function ModelicaInternal_countLines(fileName::String)::Int64
  result = Ref{Cint}(0)
  rc = ccall(
    (:safe_ModelicaInternal_countLines, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Ref{Cint}),
    fileName, result,
  )
  rc != 0 && error("ModelicaInternal_countLines failed: ", get_modelica_error())
  return Int64(result[])
end

"""
    ModelicaInternal_fullPathName(fileName) -> String

Return the full (absolute) path name of a file.
"""
function ModelicaInternal_fullPathName(fileName::String)::String
  result = Ref{Cstring}(C_NULL)
  rc = ccall(
    (:safe_ModelicaInternal_fullPathName, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Ref{Cstring}),
    fileName, result,
  )
  rc != 0 && error("ModelicaInternal_fullPathName failed: ", get_modelica_error())
  return result[] == C_NULL ? "" : unsafe_string(result[])
end

"""
    ModelicaInternal_stat(name) -> Int64

Return Modelica FileType: 1=NoFile, 2=RegularFile, 3=Directory, 4=SpecialFile.
"""
function ModelicaInternal_stat(name::String)::Int64
  result = Ref{Cint}(0)
  rc = ccall(
    (:safe_ModelicaInternal_stat, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring, Ref{Cint}),
    name, result,
  )
  rc != 0 && error("ModelicaInternal_stat failed: ", get_modelica_error())
  return Int64(result[])
end

"""
    ModelicaStreams_closeFile(fileName)

Close a file that was opened for reading via ModelicaInternal_readLine.
"""
function ModelicaStreams_closeFile(fileName::String)
  rc = ccall(
    (:safe_ModelicaStreams_closeFile, installedLibPathlibModelicaCallbacks),
    Cint,
    (Cstring,),
    fileName,
  )
  rc != 0 && error("ModelicaStreams_closeFile failed: ", get_modelica_error())
  return nothing
end
