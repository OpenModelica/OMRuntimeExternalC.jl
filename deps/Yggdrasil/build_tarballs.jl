# Draft of the Yggdrasil recipe for ModelicaExternalC_jll (https://github.com/JuliaPackaging/Yggdrasil),
# not submitted: it builds libModelicaExternalC with the script of this package, for every platform.
# The sources are the Modelica Standard Library C sources (tag v4.1.0) and this package, at the commit
# with src/C/ModelicaCallbacks.c and deps/build_libraries.sh. Replace <commit> before use.
#
# With a JLL the package would load the library from ModelicaExternalC_jll (libModelicaExternalC,
# libModelicaExternalC_path) in place of the artifact of Artifacts.toml; src/Library.jl is the only file
# that would change.
using BinaryBuilder, Pkg

name = "ModelicaExternalC"
version = v"4.1.0"

sources = [
    GitSource("https://github.com/modelica/ModelicaStandardLibrary.git",
              "8ae3d35c24e519cb2996cab20f3b13daf2b0c50a"),
    GitSource("https://github.com/OpenModelica/OMRuntimeExternalC.jl.git", "<commit>"),
]

script = raw"""
cd ${WORKSPACE}/srcdir
case "${target}" in
  *-apple-*)     export TARGET_OS=Darwin ;;
  *-mingw*)      export TARGET_OS=MINGW ;;
  *)             export TARGET_OS=Linux ;;
esac
OMRuntimeExternalC.jl/deps/build_libraries.sh ModelicaStandardLibrary/Modelica/Resources/C-Sources build
install -Dm755 build/libModelicaExternalC.* -t "${libdir}"
install_license OMRuntimeExternalC.jl/LICENSE.md OMRuntimeExternalC.jl/THIRD_PARTY_LICENSES.md
"""

platforms = supported_platforms()

products = [
    LibraryProduct("libModelicaExternalC", :libModelicaExternalC),
]

dependencies = Dependency[]

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat = "1.6")
