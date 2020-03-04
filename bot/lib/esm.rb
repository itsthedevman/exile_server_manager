# frozen_string_literal: true

require "action_view"
require "action_view/helpers"
require "active_record"
require "active_support"
require "active_support/all"
require "base64"
require "discordrb"
require "dotenv"
require "dotiw"
require "eventmachine"
require "faye/websocket"
require "httparty"
require "i18n/backend/fallbacks"
require "otr-activerecord"
require "puma"
require "puma/binder"
require "puma/events"
require "securerandom"
require "steam_web_api"
require "steam-condenser"
require "symmetric-encryption"
require "yaml"

Dotenv.load
Dotenv.load(".env.test") if ENV["ESM_ENV"] == "test"

require "esm/extension"
require "esm/color"
require "esm/embed"
require "esm/regex"

require "esm/exception"
require "esm/esm"
require "esm/bot"
require "esm/command"
require "esm/database"
require "esm/event"
require "esm/model"
require "esm/service"
require "esm/websocket"

# The load order for this is weird. If it's in the bot, it won't work for loading arguments
I18n.load_path += Dir[File.expand_path("config/locales/**") + "/*.yml"]
I18n.default_locale = "en-US"
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
