<img src="./esm.png" alt="esm logo">
<p align="center">
	<a href="https://www.ruby-lang.org/en/">
		<img src="https://img.shields.io/badge/Ruby-v3.2.2-green.svg" alt="ruby version">
	</a>
	<a href="https://www.esmbot.com/releases">
		<img src="https://img.shields.io/badge/ESM-v2.3.2-blue.svg" alt="ruby version">
	</a>
</p>

Exile Server Manager (ESM) is a Discord Bot that interfaces with Exile servers via an Arma 3 server side mod. ESM provides commands and functionality for both players and admins.

## Table of Contents

- [Links](#links)
- [Suggestions](#suggestions)
- [Developing](#developing)
- [Contributing](#contributing)
- [License](#license)

## Links

#### [Website](https://esmbot.com)

#### [Getting started](https://esmbot.com/getting_started)

#### [Join our Discord](https://esmbot.com/join)

#### [Invite ESM to your Discord](https://esmbot.com/invite)

## Suggestions

ESM was and still is built for the Exile community with a majority of ESM's features started out as suggestions. If you would like to make a suggestion, please join our <a href="https://esmbot.com/join">Discord</a> and post it in the #suggestions channel.

## Developing

You will need the following:
- Linux
- Docker (and Compose) installed
- A Discord app setup as a bot
- Experience with Ruby, Discordrb, ActiveSupport/ActiveRecord, RSpec, PostgreSQL, and Redis

### Setup

1. Clone the repository
2. Duplicate `.env.example`, rename it to `.env`, and fill out the values for the variables
3. Start the databases: `docker compose up -d postgres-db redis-db`
4. Install Ruby (I recommend [asdf](https://asdf-vm.com/) and [asdf-ruby](https://github.com/asdf-vm/asdf-ruby))
5. Install `bundler`: `gem install bundler`
6. Set up the database: `bin/setup`
7. Start the bot: `bin/dev`


## License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>

Exile Server Manager work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
