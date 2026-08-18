# frozen_string_literal: true

# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⣄⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⣄⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⣄⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⡀⡀⣄⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣄⡀⡀⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⡀⡀⡀⡀⣄⣾⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣿⣿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣿⣿⣿⣿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣄⣿⣿⣿⣿⣿⣿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⡀⡀⡀⡀⣄⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⡀⡀⣄⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⡀⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⡀⡀⣄⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⡀⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⡀⡀⣄⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⡀⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀⣄⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⡀⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
# ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
#
#                                          ##     #####
#           ###########                   #####   #####
#           ###########                    ###    #####
#           ####                                  #####        ####
#           ####          #####   #####   ####    #####    ###########
#           ##########     ##### ####     ####    #####   #####    ####
#           ##########      ########      ####    #####   ####     ####
#           ####             ######       ####    #####   #############
#           ####            ########      ####    #####   ####
#           ####           ####  #####    ####    #####   #####      ##
#           ###########   ####    #####   ####    #####     ###########
#
#     ##########
#    ####     #
#    ####           ##########    ######### ####      ####   ##########    #########
#     #######      ####    ####   ######     ####    ####   ####    ####   ######
#        ######    ############   ####        ####  ####    ############   ####
#           ####   ###            ####         #### ###     ###            ####
#   ##      ####   ####           ####          #######     ####           ####
#   ###########     ###########   ####          ######       ###########   ####
#
#   ###       ####
#   ####     #####
#   #####   ######   #######    ## #####    #######    ##### ##    ######    ## ###
#   ## ##   ## ###        ###   ###   ###        ###  ###   ###   ###   ###  ####
#   ## ### ##  ###   ########   ##    ###   ########  ###    ##  ##########  ###
#   ##  ## ##  ###  ###   ###   ##    ###  ###   ###  ###   ###   ##         ###
#   ##   ###   ###  #########   ##    ###  #########   ########   ########   ###
#                                                           ###
#                                                     #########
#

#
#  Welcome! I hope you enjoy your stay.
#

#
# Bot entry point. Boot is split into four ordered sections:
#
#   1. Gem requires and path constants (top half of this file).
#   2. `pre_init/`: library setup that runs *before* the bot's ESM module
#      is reopened (Dotenv, I18n, ActiveSupport, core gem load, etc.).
#   3. `module ESM` (middle of this file): the public API surface.
#   4. `post_init/`: ESM-aware setup that runs *after* the module exists
#      (DB connect, Zeitwerk config, signal handler class, dev tweaks).
#
# The actual bot runtime then lives in {ESM.run!}.
#

[
  # `sucker_punch` performs a `defined?(Rails)` check at load time. The
  # action/active gems below define `Rails`, so sucker_punch must load
  # first or it picks up Rails-mode behavior we don't want.
  "sucker_punch",
  "uri",

  "action_view",
  "action_view/helpers",
  "active_record",
  "active_support",
  "active_support/all",
  "activerecord-import",
  "base64",
  "colorize",
  "concurrent",
  "config",
  "discordrb",
  "dotiw",
  "everythingrb/prelude",
  "everythingrb/all",
  "eventmachine",
  "fast_jsonparser",
  "faye/websocket",
  "httparty",
  "i18n",
  "neatjson",
  "openssl",
  "puma",
  "puma/events",
  "pry",
  "redis",
  "securerandom",
  "semantic",
  "socket",
  "terminal-table",
  "yaml",
  "zeitwerk"
].each { |gem| require gem }

#############################################
# Loader
#
# A single loader to rule them all
#############################################

require Pathname.new(ENV.fetch("ESM_CORE_PATH")).join("lib", "loader.rb")

#############################################
# Path constants
#
#############################################

ESM_ROOT_PATH = Loader.root_path
ESM_SERVICE_PATH = Loader.service_path
ESM_CORE_PATH = Loader.core_path

#############################################
# pre_init
#############################################

Loader.dir("service", "lib", "pre_init")

#############################################
# module ESM
#
# Reopens the module defined by the core gem (loaded in pre_init/02) and
# layers on the bot-specific API: runtime config, connections, and the
# {ESM.run!} entry point.
#############################################

module ESM
  # Connection options passed to {Redis.new} from {.redis}. `reconnect_attempts`
  # protects against transient redis hiccups during long-running operations.
  REDIS_OPTS = {
    host: ENV.fetch("REDIS_HOST", "localhost"),
    reconnect_attempts: 10
  }.freeze

  class << self
    ##
    # The Discord bot instance used to send and receive messages.
    #
    # @return [ESM::Discord::Bot] memoized
    #
    def discord_bot
      @discord_bot ||= ESM::Discord::Bot.new
    end

    ##
    # Boots the bot
    #
    # Blocks until shutdown unless `async: true`.
    #
    # @param async [Boolean] when true, the Discord connection runs in a
    #   background thread and this method returns immediately. Defaults to false.
    # @param bare [Boolean] when true, ESM loads its code, connects to Discord, but does not start any extra services
    #   such as the API, Discord events, Arma connections, and extra services. Used in parallel when ESM is running
    #   in another process, such as bin/console and rake tasks
    #
    # @return [void]
    #
    def run!(async: false, bare: false)
      trace!("Trace logging enabled")
      debug!("Debug logging enabled")

      info!("Starting Exile Server Manager...")

      load! unless loader.setup? && loader.eager_loaded?

      # Allow the bot to override core's shared models on a per-name basis.
      # For every file in core/lib/esm/models, if a matching file exists in
      # the bot's lib/esm/model, load the bot's version so it wins.
      Dir[ESM_CORE_PATH.join("lib", "esm", "models", "*.rb")]
        .map { |path| File.basename(path, "*.rb") }
        .map { |filename| root.join("lib", "esm", "model", filename) }
        .select(&:exist?)
        .each { |path| load path }

      if env.development? && !bare
        # Seed the server tokens into redis so the dev TCP listener can validate local Arma servers without
        # waiting for a real handshake. Each server gets its own slot, keyed by server_id, so that several
        # running at once each pick up their own key instead of racing for one. The unnamespaced slot stays
        # for the first server: the spec suite writes there, since its server comes from a factory and no
        # config could name that slot ahead of time.
        servers = Server.all.to_a

        servers.each { |server| redis.set("server_key:#{server.server_id}", server.token.to_json) }
        redis.set("server_key", Server.find_by(server_id: "esm_malden").token.to_json) if servers.any?
      end

      SignalHandler.start unless env.test?
      Website::API::Server.start unless bare || env.test?

      # Load commands
      ESM::Command.load

      if !bare
        # Run some jobs for command
        SyncCommandConfigurationsJob.perform_async(nil)
        SyncCommandCountsJob.perform_async(nil)
      end

      discord_bot.run(async:, bare:)
    end

    ##
    # Sets up the Zeitwerk loader and eager-loads every constant under
    # `lib/esm/`. Idempotent; safe to call more than once but normally
    # invoked once from {.run!}.
    #
    # @return [void]
    #
    def load!
      loader.setup
      loader.eager_load
    end

    ##
    # The bot's project root.
    #
    # @return [Pathname]
    #
    def root
      @root ||= ESM_SERVICE_PATH
    end

    ##
    # Thread-safe Redis client, pooled so concurrent callers don't serialize
    # on a single connection.
    #
    # @return [ConnectionPool::Wrapper<Redis>]
    #
    def redis
      @redis ||= ConnectionPool::Wrapper.new do
        Redis.new(**REDIS_OPTS)
      end
    end

    ##
    # ActiveSupport cache backed by Redis, namespaced to `esm_bot` so keys
    # never collide with other apps sharing the same Redis instance. Tests get
    # their own namespace because they key entries on database primary keys that
    # are recycled from one run to the next, so a shared keyspace lets a stale
    # entry answer for an unrelated record.
    #
    # @return [ActiveSupport::Cache::RedisCacheStore]
    #
    def cache
      @cache ||= ActiveSupport::Cache::RedisCacheStore.new(
        namespace: env.test? ? "esm_bot_test" : "esm_bot",
        redis: redis
      )
    end

    ##
    # Current runtime environment, wrapped in an Inquirer for predicate-style
    # checks:
    #
    #   ESM.env.development?
    #   ESM.env.production?
    #
    # Reads `ESM_ENV`; defaults to `:development` when unset.
    #
    # @return [Inquirer] one of :production, :staging, :test, :development
    #
    def env
      @env ||= Inquirer.new(:production, :staging, :test, :development).set(ENV["ESM_ENV"].presence || :development)
    end

    ##
    # The Settings tree, loaded in {pre_init/01_settings.rb}. Exposed under
    # `ESM.config` for back-compat with existing call sites; new code should
    # reference `Settings` directly.
    #
    # @return [Config::Options]
    #
    def config
      Settings
    end

    ##
    # The Zeitwerk loader. Configured in `post_init/03_zeitwerk.rb`; set up
    # and eager-loaded by {.load!}.
    #
    # @return [Zeitwerk::Loader]
    #
    def loader
      @loader ||= begin
        Zeitwerk::Loader.attr_predicate(:setup, :eager_loaded)
        Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      end
    end

    ##
    # Backtrace cleaner that strips noise (gem paths, nix store paths) from
    # exception traces so logs stay focused on ESM code.
    #
    # @return [ActiveSupport::BacktraceCleaner]
    #
    def backtrace_cleaner
      @backtrace_cleaner ||= begin
        cleaner = ActiveSupport::BacktraceCleaner.new

        cleaner.add_filter { |line| line.gsub(root.to_s, "") }

        cleaner.add_silencer do |line|
          /\/ruby.gems|\/nix/.match?(line)
        end

        cleaner
      end
    end
  end
end

#############################################
# post_init
#############################################

Loader.dir("service", "lib", "post_init")
