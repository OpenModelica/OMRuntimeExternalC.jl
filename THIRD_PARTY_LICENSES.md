# Third-party licenses

OMRuntimeExternalC itself (the Julia code, `src/C/ModelicaCallbacks.c`, the build scripts) is under the OSMC Public License (OSMC-PL) 1.8 ([LICENSE.md](LICENSE.md)).
The C files of the Modelica Standard Library listed below are the MSL's: the license of the MSL applies to them, not the OSMC-PL.

`libModelicaExternalC` (the shared library the package loads, built by `deps/build_libraries.sh`) is
compiled from the C sources of the Modelica Standard Library (MSL), tag `v4.1.0`, commit
`8ae3d35c24e519cb2996cab20f3b13daf2b0c50a`, directory `Modelica/Resources/C-Sources`, and the shim
`src/C/ModelicaCallbacks.c` of this package. The library is a combined work: the shim is under
the OSMC-PL, each MSL source under the license named in its own header, as listed here. This file ships with the library (`share/licenses/ModelicaExternalC`).

| Compiled into the library | Copyright holders (from the file headers) | License |
|---|---|---|
| `ModelicaStandardTables.c`, `ModelicaStandardTablesUsertab.c`, `ModelicaIO.c`, `ModelicaInternal.c`, `ModelicaStrings.c`, `ModelicaRandom.c`, `ModelicaFFT.c`, headers `Modelica*.h` | Modelica Association and contributors | BSD 3-Clause (text below) |
| `ModelicaFFT.c`: the FFT of kiss_fft | Mark Borgerding (2003-2010) | BSD 3-Clause (the same file header) |
| `ModelicaMatIO.c`: matio, concatenated | The matio contributors (2015-2024), Christopher C. Hulbert (2005-2014), Modelica Association and contributors | BSD 3-Clause (the same file header) |
| `snprintf.c` | Patrick Powell (1995), Holger Weiss (2008) | Permissive notices of the file: use "for any purpose as long as this notice remains intact" (Powell); free use, modification and redistribution "for any purpose" (Weiss) |
| `zlib/*.c` (15 files) | Jean-loup Gailly and Mark Adler (1995-2024), zlib 1.3.1 | zlib license (text below) |
| `gconstructor.h` (macros for constructors; included by `ModelicaInternal.c` and `ModelicaRandom.c`) | GLib (the file has no license header in the MSL) | Origin: GLib, LGPL-2.1-or-later (see the open point below) |

Not compiled into the library: `uthash.h` (BSD, Troy D. Hanson; used only when `TABLE_SHARE` is set, it is not),
`safe-math.h` (CC0 1.0, Evan Nemerson), `win32_dirent.c` (public domain, Visual C++ only), `stdint_msvc.h`.

The library links no other library than the C library of the platform. It contains no code of the OpenModelica
runtime, BLAS, SUNDIALS or gettext.

Open point: the MSL copy of `gconstructor.h` carries no license text. Its origin is GLib's file of the same name (LGPL-2.1-or-later).
It only defines the macros that run a function when the library loads and unloads.

## BSD 3-Clause (Modelica Association and contributors)

```
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## zlib license (Jean-loup Gailly and Mark Adler)

```
This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
```
