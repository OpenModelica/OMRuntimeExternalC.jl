@info "Building OMRuntimeExternalC"

using HTTP
import ZipFile
import Tar
import Inflate

const DEPS_DIR = @__DIR__
const PACKAGE_DIR = dirname(DEPS_DIR)
const PATH_TO_EXT = joinpath(PACKAGE_DIR, "lib", "ext")
const RELEASE_BASE_URL = "https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/libs-v0.1.0"
const CALLBACKS_VERSION = "v0.1.0"
const CALLBACKS_BASE_URL = "https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/$(CALLBACKS_VERSION)"

function downloadAndExtractLibraries(libraryString; URL)
  @info "Downloading archive from $(URL)..."
  mkpath(PATH_TO_EXT)

  local zipPath = joinpath(PATH_TO_EXT, libraryString * ".zip")
  HTTP.download(URL, zipPath)

  local sharedDir = joinpath(PATH_TO_EXT, "shared")
  mkpath(sharedDir)

  @info "Extracting to $(sharedDir)..."
  r = ZipFile.Reader(zipPath)
  for f in r.files
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
  rm(zipPath)

  @info "Successfully extracted libraries to $(sharedDir)/$(libraryString)/"
end

function downloadCallbacksShim(libSubdir::String)
  local url = "$(CALLBACKS_BASE_URL)/$(libSubdir)-callbacks.tar.gz"
  local outDir = joinpath(PATH_TO_EXT, "shared", libSubdir)
  mkpath(outDir)

  local ext = Sys.iswindows() ? ".dll" : Sys.isapple() ? ".dylib" : ".so"
  local outFile = joinpath(outDir, "libModelicaCallbacks$ext")
  if isfile(outFile)
    @info "ModelicaCallbacks shim already exists at $outFile"
    return
  end

  @info "Downloading ModelicaCallbacks shim from $(url)..."
  try
    local tgzPath = joinpath(PATH_TO_EXT, "$(libSubdir)-callbacks.tar.gz")
    HTTP.download(url, tgzPath)
    open(tgzPath) do io
      Tar.extract(Inflate.inflate_gzip(io), outDir)
    end
    rm(tgzPath)
    @info "Successfully installed ModelicaCallbacks shim to $outDir"
  catch e
    @warn "Failed to download pre-built ModelicaCallbacks shim: $e"
    @info "Attempting to compile from source..."
    buildModelicaCallbacksFromSource(libSubdir)
  end
end

function buildModelicaCallbacksFromSource(libSubdir::String)
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

  try
    run(compileCmd)
    @info "Successfully compiled ModelicaCallbacks shim"
  catch e
    @warn "Failed to compile ModelicaCallbacks shim: $e"
  end
end

@static if Sys.iswindows()
  downloadAndExtractLibraries("x86_64-mingw32";
                              URL="$(RELEASE_BASE_URL)/x86_64-mingw32.zip")
  downloadCallbacksShim("x86_64-mingw32")
elseif Sys.islinux()
  downloadAndExtractLibraries("x86_64-linux-gnu";
                              URL="$(RELEASE_BASE_URL)/x86_64-linux-gnu.zip")
  downloadCallbacksShim("x86_64-linux-gnu")
elseif Sys.isapple()
  @warn "macOS: Modelica external C libraries are not yet available."
  local arch = Sys.ARCH == :aarch64 ? "aarch64-apple-darwin" : "x86_64-apple-darwin"
  downloadCallbacksShim(arch)
else
  @warn "This platform is not supported."
end
