#= Build the documentation: `julia --project=docs docs/make.jl`. Deploys to gh-pages only on CI. =#
using Documenter
using OMRuntimeExternalC

makedocs(
  sitename = "OMRuntimeExternalC.jl",
  modules = [OMRuntimeExternalC],
  authors = "Adrian Pop <adrian.pop@liu.se>, John Tinnerholm <john.tinnerholm@liu.se>",
  repo = Documenter.Remotes.GitHub("OpenModelica", "OMRuntimeExternalC.jl"),
  format = Documenter.HTML(;
    prettyurls = get(ENV, "CI", "false") == "true",
    canonical = "https://OpenModelica.github.io/OMRuntimeExternalC.jl",
    edit_link = "master",
  ),
  pages = [
    "Home" => "index.md",
    "API reference" => "api.md",
  ],
  #= Nothing is exported; the API page lists the docstrings of src/Library.jl and src/api.jl. =#
  checkdocs = :exports,
)

if get(ENV, "CI", "false") == "true"
  deploydocs(repo = "github.com/OpenModelica/OMRuntimeExternalC.jl.git", devbranch = "master")
end
