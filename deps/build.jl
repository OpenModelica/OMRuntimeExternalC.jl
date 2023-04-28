@info "Building OMRuntimeExternal C"

import Inflate
import Tar
import ZipFile

function downloadAndextractTar(libraryString; URL)
  @info "Downloading archive..."
  HTTP.download(URL, PATH_TO_EXT)
  println(pwd())
  cd(PATH_TO_EXT)
  println(pwd())
  foreach(readdir()) do f
    println("\nObject: ", f)
  end
  @info "Deflating downloaded files..."
  r = ZipFile.Reader(libraryString * ".zip")
  for f in r.files
    @info "Extracting..." f.name
    fileName = replace(f.name, "$(libraryString)/" => "")
    if ! isempty(fileName)
      @info "Writing..." fileName
      write(fileName, read(f, String))
    end
  end
  close(r)
  @info "Sucessfully extracted downloaded files!"
  @info "The following DLL was extracted:" libraryString
  @info "Deflating done!"
  # Script part to be added once we have a tar.gz scheme up and running -John
  # @info "Decompressing archive.."
  # local res = Inflate.inflate_gzip(string(libraryString, ".tar.gz"))
  # local tarName = string(libraryString, ".tar")
  # write(tarName, res)
  # @info "Done. .tar created."
  # @info "...Extracting the files in the tar..."
  # @info "----------------------------------------"
  # try
  #   rm("shared", recursive=true)
  # catch #= Silence on failure =#
  # end
  # dir = Tar.extract(tarName, "shared")
  # @info dir
  # @info "----------------------------------------"
  # @info "Download external shared libraries done!"
  # foreach(readdir()) do f
  #   @info "\nObject: " f
  # end
  # @info "----------------------------------------"
end


using HTTP
#=Extern path=#
const PATH_TO_EXT = realpath("$(pwd())/../lib/ext")
@static if Sys.iswindows()
  #= Download shared libraries (DLLS for Windows)=#
  downloadAndextractTar("x86_64-mingw32";
                        URL="https://build.openmodelica.org/omc/julia/x86_64-mingw32.zip")
elseif Sys.islinux()
  throw("Linux not yet supported")
elseif Sys.isapple()
  throw("Apple not yet supported")
else#= Throw error for other variants =#
  @error "Non Linux/Windows systems are currently not supported"
  throw("Unsupported system error")
end
