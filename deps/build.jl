@info "Building OMRuntimeExternalC"

using HTTP
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

    local resp = HTTP.get(RELEASES_API_URL; headers = headers, status_exception = true)
    # The API lists releases newest-first; pull tag_names without a JSON dep.
    local tags = [m.captures[1] for m in eachmatch(r"\"tag_name\"\s*:\s*\"([^\"]+)\"", String(resp.body))]
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
                              URL="$(releaseBaseURL())/x86_64-mingw32.zip")
  downloadCallbacksShim("x86_64-mingw32")
elseif Sys.islinux()
  downloadAndExtractLibraries("x86_64-linux-gnu";
                              URL="$(releaseBaseURL())/x86_64-linux-gnu.zip")
  downloadCallbacksShim("x86_64-linux-gnu")
elseif Sys.isapple()
  @warn "macOS: Modelica external C libraries are not yet available."
  local arch = Sys.ARCH == :aarch64 ? "aarch64-apple-darwin" : "x86_64-apple-darwin"
  downloadCallbacksShim(arch)
else
  @warn "This platform is not supported."
end
