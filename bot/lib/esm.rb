# frozen_string_literal: true

# Welcome to Exile Server Manager!
#   I hope you enjoy your stay.
#
# Just fyi, this file is laid out in a particular order so
#   I can access ESM.env and ESM.config when all other files load

# This contains a check for the existence of the Rails class.
# One of the action/active gems defines Rails, so this needs to be loaded first
require "sucker_punch"

require "action_view"
require "action_view/helpers"
require "active_record"
require "activerecord-import"
require "active_support"
require "active_support/all"
require "base64"
require "discordrb"
require "dotenv"
require "dotiw"
require "eventmachine"
require "faye/websocket"
require "httparty"
require "i18n"
require "otr-activerecord"
require "puma"
require "puma/events"
require "securerandom"
require "sinatra/base"
require "steam_web_api"
require "steam-condenser"
require "terminal-table"
require "yaml"
require "zeitwerk"

# Load Dotenv variables
Dotenv.load
Dotenv.load(".env.test") if ENV["ESM_ENV"] == "test"

module ESM
  class << self
    attr_reader :bot, :config, :logger, :env
  end

  def self.run!
    load_i18n
    initialize_steam
    initialize_logger

    # Subscribe to notifications
    ESM::Notifications.subscribe

    # Start the bot
    @bot = ESM::Bot.new

    if ESM.env.test? || @console
      # Allow RSpec to continue
      Thread.new { @bot.run }
    else
      @bot.run
    end
  end

  # Allow IRB to be not-blocked by ESM's main thread
  def self.console!
    @console = true
  end

  def self.load_i18n
    I18n.load_path += Dir[File.expand_path("config/locales/**") + "/*.yml"]
    I18n.reload!
  end

  def self.initialize_steam
    SteamWebApi.configure do |config|
      config.api_key = @config.steam_api_key
    end
  end

  def self.initialize_logger
    @logger = Logger.new("logs/#{env}.log")

    @logger.formatter = proc do |severity, datetime, progname = "N/A", msg|
      header = "#{severity} [#{datetime.strftime("%F %H:%M:%S:%L")}] (#{progname})"
      body = "\n\t#{msg.to_s.gsub("\n", "\n\t")}\n\n"

      if ENV["PRINT_LOG"] == "true"
        header =
          case severity
          when "INFO"
            header.colorize(:light_blue)
          when "DEBUG"
            header.colorize(:magenta)
          when "WARN"
            header.colorize(:yellow)
          when "ERROR", "FATAL"
            header.colorize(:red)
          else
            header
          end

        body =
          case severity
          when "INFO"
            body.colorize(:light_black)
          when "DEBUG"
            body.colorize(:light_black)
          when "WARN"
            body.colorize(:yellow)
          when "ERROR", "FATAL"
            body.colorize(:red)
          else
            body
          end

        puts "#{header}#{body}"
      end

      "#{header}#{body}"
    end
  end

  # Borrowed from Rails, load the ENV
  # https://github.com/rails/rails/blob/master/railties/lib/rails.rb:72
  @env ||= ActiveSupport::StringInquirer.new(ENV["ESM_ENV"].presence || "development")

  # Load the config
  config = YAML.safe_load(ERB.new(File.read(File.expand_path("config/config.yml"))).result, aliases: true)[self.env]
  @config = JSON.parse(config.to_json, object_class: OpenStruct)
end

# Run pre_init (Throwback to Exile)
require_relative "pre_init"
require_relative "pre_init_dev"
