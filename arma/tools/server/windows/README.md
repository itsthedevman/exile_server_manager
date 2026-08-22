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

## Reaching the server from outside

`bin/build --target=windows` opens the instance's UDP port range (`port` through `port + 4`) through Windows
Firewall on every start, so nothing here needs doing by hand. Worth knowing what it is for: the firewall is on by
default for all three profiles, Arma binds `0.0.0.0` and answers nothing from outside it, and the result reads as
a server that started but never came up. Steam A2S is what notices first, because `server details` gets its map,
player count and game version from it.

A2S is also the one part of the spec suite that talks to the server directly instead of through the bot, so it is
the one part that has to know where the server is. Point it at the host:

```sh
export ESM_ARMA_QUERY_HOST=<host>   # service/.envrc.local
```

Without it the query specs aim at `127.0.0.1`, where the Docker container publishes its ports and a remote host
has nothing listening.
