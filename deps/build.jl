@info "Building OMRuntimeExternalC"

using HTTP
import ZipFile

const DEPS_DIR = @__DIR__
const PACKAGE_DIR = dirname(DEPS_DIR)
const PATH_TO_EXT = joinpath(PACKAGE_DIR, "lib", "ext")
const RELEASE_BASE_URL = "https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/libs-v0.1.0"

function downloadAndExtractLibraries(libraryString; URL)
  @info "Downloading archive from $(URL)..."

  #= Ensure the lib/ext directory exists =#
  mkpath(PATH_TO_EXT)

  local zipPath = joinpath(PATH_TO_EXT, libraryString * ".zip")
  HTTP.download(URL, zipPath)

  #= Create shared directory if it does not exist =#
  local sharedDir = joinpath(PATH_TO_EXT, "shared")
  mkpath(sharedDir)

  @info "Extracting to $(sharedDir)..."
  r = ZipFile.Reader(zipPath)
  for f in r.files
    #= Skip directory entries =#
    if endswith(f.name, "/")
      continue
    end
    local outPath = joinpath(sharedDir, f.name)
    local outDir = dirname(outPath)
    mkpath(outDir)
    @info "Extracting: $(f.name)"
    write(outPath, read(f))
  end
  close(r)

  #= Clean up the zip file =#
  rm(zipPath)

  @info "Successfully extracted libraries to $(sharedDir)/$(libraryString)/"
end

function buildModelicaCallbacks(libSubdir::String)
  local srcFile = joinpath(PACKAGE_DIR, "src", "modelica_callbacks.c")
  local outDir = joinpath(PATH_TO_EXT, "shared", libSubdir)
  mkpath(outDir)

  local ext, compileCmd
  if Sys.islinux()
    ext = ".so"
    compileCmd = `gcc -shared -fPIC -o $(joinpath(outDir, "libModelicaCallbacks$ext")) $srcFile -ldl`
  elseif Sys.isapple()
    ext = ".dylib"
    compileCmd = `cc -dynamiclib -fPIC -o $(joinpath(outDir, "libModelicaCallbacks$ext")) $srcFile -ldl`
  elseif Sys.iswindows()
    ext = ".dll"
    compileCmd = `gcc -shared -o $(joinpath(outDir, "libModelicaCallbacks$ext")) $srcFile`
  else
    @warn "Cannot build ModelicaCallbacks: unsupported platform"
    return
  end

  local outFile = joinpath(outDir, "libModelicaCallbacks$ext")
  if isfile(outFile)
    @info "ModelicaCallbacks shim already exists at $outFile"
    return
  end

  @info "Compiling ModelicaCallbacks shim..."
  try
    run(compileCmd)
    @info "Successfully built $outFile"
  catch e
    @warn "Failed to compile ModelicaCallbacks shim: $e"
    @warn "External C functions (ModelicaIO, ModelicaInternal) may not handle errors safely."
  end
end

@static if Sys.iswindows()
  downloadAndExtractLibraries("x86_64-mingw32";
                              URL="$(RELEASE_BASE_URL)/x86_64-mingw32.zip")
  buildModelicaCallbacks("x86_64-mingw32")
elseif Sys.islinux()
  downloadAndExtractLibraries("x86_64-linux-gnu";
                              URL="$(RELEASE_BASE_URL)/x86_64-linux-gnu.zip")
  buildModelicaCallbacks("x86_64-linux-gnu")
elseif Sys.isapple()
  @warn "macOS: Modelica external C libraries are not yet available."
  local arch = Sys.ARCH == :aarch64 ? "aarch64-apple-darwin" : "x86_64-apple-darwin"
  buildModelicaCallbacks(arch)
else
  @warn "This platform is not supported."
  @warn "Some functionality requiring external C libraries will not be available."
end
