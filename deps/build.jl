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

@static if Sys.iswindows()
  downloadAndExtractLibraries("x86_64-mingw32";
                              URL="$(RELEASE_BASE_URL)/x86_64-mingw32.zip")
elseif Sys.islinux()
  downloadAndExtractLibraries("x86_64-linux-gnu";
                              URL="$(RELEASE_BASE_URL)/x86_64-linux-gnu.zip")
elseif Sys.isapple()
  @warn "macOS is currently not supported due to dylib path issues in the OpenModelica build system."
  @warn "See: https://trac.openmodelica.org/OpenModelica/ticket/4647"
  @warn "Some functionality requiring external C libraries will not be available."
else
  @warn "This platform is not supported."
  @warn "Some functionality requiring external C libraries will not be available."
end
