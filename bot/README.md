<div align="center">
  <br>
  <h1>Exile Server Manager</h1>
  <strong>A multi-faceted Discord Bot for Arma 3 Exile</strong>
</div>
<br>
<p align="center">
  <a href="https://www.ruby-lang.org/en/">
    <img src="https://img.shields.io/badge/Ruby-v2.7.2-green.svg" alt="ruby version">
  </a>
  <a href="https://www.esmbot.com/releases">
    <img src="https://img.shields.io/badge/ESM-v2.0-blue.svg" alt="ruby version">
  </a>
</p>

# What is Exile Server Manager?
Exile Server Manager, or ESM for short, is a Discord Bot that facilitates interacting with an Arma 3 Exile server. Server owners and players alike can link their Steam accounts with ESM to enable running various commands to interact with their characters on any server they have joined.

## Suggestions
ESM was and still is built for the Exile community with a majority of ESM's features started out as suggestions. If you would like to make a suggestion, please join our <a href="https://esmbot.com/join">Discord</a> and post it in the #suggestions channel.

## Before continuing...
Are you a server owner or player looking to use Exile Server Manager? If so, please visit my <a href="https://www.esmbot.com/wiki">Getting Started</a> section of the Wiki as this README is focused on the development side of ESM.

## Getting Started
ESM is written in MRI Ruby 2.7.2 with DiscordRB 3.4 and PostgreSQL 12. I, personally, use <a href="https://rvm.io/">RVM</a> to manage Ruby, but ESM is not dependent on it. This README is still work in progress and will expand over time.

## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />Exile Server Manager work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

# Beyond here lies wips

## ESM's life cycle
TODO DESCRIPTION

### Bootstrap

**File:** <span id="bin-esm">`bin/esm.rb`</span>

- [`lib/esm.rb`](#lib-esm) is executed
- The bot is started

**File:** <span id="lib-esm">`lib/esm.rb`</span>

- Dependencies are loaded
- Environment variables are loaded
- ESM module defined
- [lib/pre_init.rb](#lib-pre_init) is executed
- [lib/pre_init_dev.rb](#lib-pre_init_dev) is executed

**File:** <span id="lib-pre_init">`lib/pre_init.rb`</span>

- Patch methods within Ruby and Discordrb classes
- ESM files are loaded

**File:** <span id="lib-pre_init_dev">`lib/pre_init_dev.rb`</span>

- Loads query trace logging
- Disables DiscordRb logging (too noisy)
- Sets ActiveRecord logging to info

### Boot
File: lib/esm.rb
Method: .run!
- Translations are loaded
- Steam integration is initialized
- Logging is initialized
- Notification events are loaded
- The bot is initialized
- The bot is started

File: lib/esm/bot.rb
Method: #initialize
- The database is connected to
- Command prefixes are loaded
- The bot is initialized

File: lib/esm/bot.rb
Method: #run
- Hooks into the required Discord events
- Loads the commands (lib/esm/commands.rb.load_commands)
- Discord is initialized

File: lib/esm/command.rb
Method: .load_commands
- Commands are loaded
- Test commands are loaded if tests are being executed
- Command metadata is cached for the website wiki
- Any new commands are added to every server's command configurations
- Any new commands are registered with the internal execution counter

File: lib/esm/command.rb
Method: .process_command
- For every command file defined in each category, the following is executed:
  - The class name is loaded from the file path
  - The command is
  - The command is registered with the bot
  - The command is cached

### Bot is connected and ready
File: lib/esm/bot.rb
Method: #esm_ready
- The bot's status is set
- The API is started
- The websocket server is started
- The accept/decline request overseer is started

File: lib/esm/api.rb
- Loads the endpoints for receiving events from the website

File: lib/esm/websocket.rb
Method: .start!
- The server is started
- The outbound request overseer is started

### A command is executed
File: lib/esm/command.rb
Method: .define
- A new instance of the executed command is initialized
- The command is executed with the event from Discord

File: lib/esm/command/base.rb
Method: #execute
- 

## Setting up the bot
This guide expects that you have knowledge and experience working with the following:

- Ruby 2+
- Environment variables
- ActiveRecord and SQL
- RSpec
- Discordrb

Steps:

- install postgres
- Install ruby
- Install bundler gem
- configure .env
- configure spec/test_users.yml
- bin/setup
