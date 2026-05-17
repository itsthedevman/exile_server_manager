<p align="center">
  <img src="esm.svg" alt="ESM Logo" width="100" height="100">
</p>
<h1 align="center">Exile Server Manager (ESM)</h1>

ESM connects Discord communities to their Exile (Arma 3) servers. Players manage territories, check server status, and receive XM8 notifications even while offline. Server owners configure commands, mods, rewards, and notifications - and monitor their servers - through Discord and a web dashboard.

## Links

- [Website](https://esmbot.com)
- [Getting Started Guide](https://esmbot.com/getting_started)
- [Discord](https://esmbot.com/join)
- [Invite ESM to your server](https://esmbot.com/invite)

## Components

This monorepo holds the four pieces that make up the ESM platform.

| Subdirectory | Component | Stack |
|---|---|---|
| [`service/`](service/README.md) | Discord bot — handles commands, events, and notifications | Ruby |
| [`core/`](core/README.md) | Shared Ruby gem with models and business logic | Ruby |
| [`website/`](website/README.md) | Web dashboard at [esmbot.com](https://esmbot.com) | Rails + Hotwire |
| [`arma/`](arma/README.md) | Arma 3 server mod and native extension | Rust + SQF |

### How the pieces fit together

The Discord **bot** receives commands from Discord users and forwards game-server actions to **arma** over an encrypted TCP connection. The **arma** Rust extension and SQF mod live on the Arma 3 server, executing actions and routing in-game events back to the bot. The **website** is the configuration and management surface for server owners and players. The bot and website share data and code through the **core** gem.

## Suggestions

ESM is built for the Exile community, and most features started as community suggestions. Share yours in the #suggestions channel on [our Discord](https://esmbot.com/join).

## For developers

Each component has its own README with requirements, setup, and architecture details:

- [`service/README.md`](service/README.md) — Discord bot
- [`core/README.md`](core/README.md) — shared Ruby gem
- [`website/README.md`](website/README.md) — Rails web dashboard
- [`arma/README.md`](arma/README.md) — Arma 3 mod and Rust extension

The repository ships a unified Nix dev shell that provides Ruby, Node, Rust, and database tooling for every subdir. From the repo root:

```bash
direnv allow   # first time only
nix develop    # or just cd into a subdir — its .envrc delegates here
```

## License

ESM is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>
