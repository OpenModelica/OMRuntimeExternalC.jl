#= Write the entries of the artifact "ModelicaExternalC" into Artifacts.toml.

     julia deps/bind_artifacts.jl <release tag> <directory with the tarballs> [<download base URL>]

   The directory holds the ModelicaExternalC.<platform>.tar.gz files that deps/package_library.sh made on
   each platform (the CI uploads them to the release <release tag>). For each one the entry has the tree
   hash of the unpacked tarball, the platform, and the download URL with the SHA-256 of the file. The
   download base URL defaults to the release's: https://github.com/OpenModelica/OMRuntimeExternalC.jl/releases/download/<tag>.
   Run it once per release, commit Artifacts.toml. =#
import Pkg
import SHA
import Base.BinaryPlatforms: Platform

const REPOSITORY = "OpenModelica/OMRuntimeExternalC.jl"
const ARTIFACT = "ModelicaExternalC"
const PREFIX = ARTIFACT * "."
const SUFFIX = ".tar.gz"

"""
    bindTarball(artifactsToml::String, tarball::String, url::String)

Add the entry of one platform: the platform is the name between `ModelicaExternalC.` and `.tar.gz`.
"""
function bindTarball(artifactsToml::String, tarball::String, url::String)
  local file::String = basename(tarball)
  local triplet::String = file[length(PREFIX) + 1:end - length(SUFFIX)]
  local platform::Platform = parse(Platform, triplet)
  local sha256::String = bytes2hex(open(SHA.sha256, tarball))
  local tree::Base.SHA1 = mktempdir() do dir::String
    Pkg.PlatformEngines.unpack(tarball, dir)
    Base.SHA1(Pkg.GitTools.tree_hash(dir))
  end
  Pkg.Artifacts.bind_artifact!(artifactsToml, ARTIFACT, tree; platform = platform,
                               download_info = [(url, sha256)], force = true)
  println(rpad(triplet, 24), " ", tree, "  ", sha256)
end

function main(args::Vector{String})
  length(args) in (2, 3) || error("usage: julia deps/bind_artifacts.jl <release tag> <directory with the tarballs> [<download base URL>]")
  local tag::String = args[1]
  local dir::String = args[2]
  local base::String = length(args) == 3 ? args[3] : "https://github.com/$REPOSITORY/releases/download/$tag"
  local toml::String = joinpath(@__DIR__, "..", "Artifacts.toml")
  local tarballs::Vector{String} = sort(filter(f -> startswith(f, PREFIX) && endswith(f, SUFFIX), readdir(dir)))
  isempty(tarballs) && error("no $PREFIX*$SUFFIX in $dir")
  for file::String in tarballs
    bindTarball(toml, joinpath(dir, file), base * "/" * file)
  end
end

main(ARGS)
