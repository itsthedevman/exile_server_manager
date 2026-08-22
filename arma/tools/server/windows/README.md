# Windows server-root files

Files that belong next to `arma3server.exe` rather than inside a mod folder.

`tbbmalloc.dll` and `tbbmalloc_x64.dll` are extDB3's allocator, from the
[extDB3](https://github.com/SteezCram/extDB3) Windows release (v1033). They have to sit in the Arma server root:
Windows resolves a DLL's dependencies against the _process_ directory, not against the directory the extension was
loaded from, so putting them beside `extDB3_x64.dll` in `@exileserver` leaves extDB3 unable to load. Exile then
shuts the server down on purpose, reporting `CallExtension 'extDB3' could not be found`, which points at the
extension rather than at the allocator it could not find.

extDB3's own DLLs are not here. Those live in `@exileserver` alongside the `.so` files they mirror, which is where
Exile looks for them.

`bin/build --target=windows` uploads this directory's contents into the server root. Nothing reads it on Linux,
where extDB3 is a `.so` with no separate allocator to place.

## Host requirements

A Windows host running an ESM dev server needs, beyond the Arma dedicated server itself:

- **Visual C++ 2015-2022 Redistributable, both x64 and x86.** Arma wants it, and so does extDB3. Install whichever
  matches the server you intend to run, or both:
  - x64: <https://aka.ms/vs/17/release/vc_redist.x64.exe>
  - x86: <https://aka.ms/vs/17/release/vc_redist.x86.exe>
- **OpenSSH Server**, since `bin/build --target=windows` drives the host over SSH.

When it is missing, the loader fails on the second hop and Arma reports it against the first:

```
Call extension 'extDB3' could not be loaded: The specified module could not be found.
"ExileServer - MySQL Error: Error Required extDB3 Version 1.027 or higher: "
```
