@info "Building OMRuntimeExternalC"

#= Downloads (stdlib), not HTTP: HTTP 2 dropped HTTP.download, and with no compat
   bound Julia 1.13 resolved HTTP 2.8, so the build downloaded nothing on Linux and
   Windows (2026-10-02). =#
import Downloads
import ZipFile
import Tar
import Inflate

const DEPS_DIR = @__DIR__
const PACKAGE_DIR = dirname(DEPS_DIR)
const PATH_TO_EXT = joinpath(PACKAGE_DIR, "lib", "ext")

const REPO_SLUG = "OpenModelica/OMRuntimeExternalC.jl"
const RELEASES_API_URL = "https://api.github.com/repos/$(REPO_SLUG)/releases"
const DOWNLOAD_BASE = "https://github.com/$(REPO_SLUG)/releases/download"

# Fallback tag, used only when the GitHub API can't be reached (offline build,
# rate-limited CI, etc.). Prebuilt binaries live on the `libs-vX.Y.Z` tag line,
# which is intentionally decoupled from the package source version (Project.toml).
const DEFAULT_RELEASE_TAG = "libs-v0.1.0"

# Resolved at build time (see resolveReleaseTag!). A Ref so it can be set after the
# `const` is declared, while the download code below reads RELEASE_TAG[].
const RELEASE_TAG = Ref{String}(DEFAULT_RELEASE_TAG)

"""
    resolveReleaseTag() -> String

Query the GitHub releases API and return the newest binary-release tag. Prefers the
`libs-` tag line; falls back to the most recent release overall, and finally to
`DEFAULT_RELEASE_TAG` if the API is unreachable. Emits @info/@warn so the build log
records which tag (and why) was chosen.
"""
function resolveReleaseTag()
  try
    @info "Resolving latest OMRuntimeExternalC release tag from GitHub..." url = RELEASES_API_URL
    local headers = ["Accept" => "application/vnd.github+json",
                     "User-Agent" => "OMRuntimeExternalC.jl-build"]
    # Use a token when available so CI doesn't hit the low anonymous rate limit.
    local token = get(ENV, "GITHUB_TOKEN", get(ENV, "GH_TOKEN", ""))
    isempty(token) || push!(headers, "Authorization" => "Bearer $(token)")

    # Downloads.download throws on a status that is not a success.
    local body = IOBuffer()
    Downloads.download(RELEASES_API_URL, body; headers = headers)
    # The API lists releases newest-first; pull tag_names without a JSON dep.
    local tags = [m.captures[1] for m in eachmatch(r"\"tag_name\"\s*:\s*\"([^\"]+)\"", String(take!(body)))]
    isempty(tags) && error("GitHub API returned no releases")

    local libsIdx = findfirst(t -> startswith(t, "libs-"), tags)
    if libsIdx === nothing
      @warn "No `libs-` release found; using most recent release tag instead" tag = first(tags)
      return first(tags)
    end
    @info "Resolved latest binary release tag" tag = tags[libsIdx]
    return tags[libsIdx]
  catch err
    @warn "Could not resolve latest release tag from GitHub; falling back to default" fallback = DEFAULT_RELEASE_TAG exception = err
    return DEFAULT_RELEASE_TAG
  end
end

RELEASE_TAG[] = resolveReleaseTag()

# Both the runtime libs and the callbacks shim are published on the same release.
releaseBaseURL() = "$(DOWNLOAD_BASE)/$(RELEASE_TAG[])"

#= Put `src` in place of `dest` by renaming it (after removing `dest`), never by
   writing into `dest`: a Julia session that has the old library loaded keeps
   its unlinked copy, whereas rewriting a loaded Mach-O can get it killed. =#
function installFile(src::String, dest::String)
  mkpath(dirname(dest))
  mv(src, dest; force = true)
end

function downloadAndExtractLibraries(libraryString; URL)
  @info "Downloading archive from $(URL)..."
  mkpath(PATH_TO_EXT)

  local zipPath = joinpath(PATH_TO_EXT, libraryString * ".zip")
  local sharedDir = joinpath(PATH_TO_EXT, "shared")
  try
    Downloads.download(URL, zipPath)
    mkpath(sharedDir)
    @info "Extracting to $(sharedDir)..."
    local r = ZipFile.Reader(zipPath)
    try
      for f in r.files
        if endswith(f.name, "/")
          continue
        end
        local outPath = joinpath(sharedDir, f.name)
        @info "Extracting: $(f.name)"
        mkpath(dirname(outPath))
        write(outPath * ".part", read(f))
        installFile(outPath * ".part", outPath)
      end
    finally
      close(r)
    end
  finally
    rm(zipPath; force = true)
  end

  @info "Successfully extracted libraries to $(sharedDir)/$(libraryString)/"
end

function downloadCallbacksShim(libSubdir::String)
  local url = "$(releaseBaseURL())/$(libSubdir)-callbacks.tar.gz"
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
    #= Tar.extract needs an empty target directory (outDir already holds the
       other libraries) and an IO, not the inflated bytes. =#
    local tmpDir = mktempdir(PATH_TO_EXT)
    try
      Downloads.download(url, tgzPath)
      Tar.extract(IOBuffer(Inflate.inflate_gzip(read(tgzPath))), tmpDir)
      for name in readdir(tmpDir)
        installFile(joinpath(tmpDir, name), joinpath(outDir, name))
      end
    finally
      rm(tmpDir; force = true, recursive = true)
      rm(tgzPath; force = true)
    end
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
                              URL="$(releaseBaseURL())/x86_64-mingw32.zip")
  downloadCallbacksShim("x86_64-mingw32")
elseif Sys.islinux()
  downloadAndExtractLibraries("x86_64-linux-gnu";
                              URL="$(releaseBaseURL())/x86_64-linux-gnu.zip")
  downloadCallbacksShim("x86_64-linux-gnu")
elseif Sys.isapple()
  #= Built from the Modelica Standard Library C sources by
     .github/workflows/macos-libs.yml (deps/build_msl_c_macos.sh). A release
     published before that workflow has no macOS asset: warn and go on, as
     before, instead of failing the build. =#
  local arch = Sys.ARCH == :aarch64 ? "aarch64-apple-darwin" : "x86_64-apple-darwin"
  try
    downloadAndExtractLibraries(arch; URL="$(releaseBaseURL())/$(arch).zip")
  catch e
    @warn "macOS: no prebuilt Modelica external C libraries in release $(RELEASE_TAG[]); " *
          "external Modelica functions will not work. To build them locally run " *
          "deps/build_msl_c_macos.sh <ModelicaStandardLibrary>/Modelica/Resources/C-Sources " *
          "lib/ext/shared/$(arch)" exception = e
  end
  downloadCallbacksShim(arch)
else
  @warn "This platform is not supported."
end
