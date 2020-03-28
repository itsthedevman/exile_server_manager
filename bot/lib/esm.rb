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
require "puma/events"
require "securerandom"
require "steam_web_api"
require "steam-condenser"
require "symmetric-encryption"
require "yaml"
require "zeitwerk"

# Run pre_init (Throwback to Exile)
require_relative "pre_init"

module ESM
  class << self
    attr_reader :bot, :config, :logger
  end

  def self.run!
    # Load our Config
    load_config

    initialize_steam
    initialize_logger
    initialize_encryption

    # Start the bot
    @bot = ESM::Bot.new

    if ESM.env.test? || @console
      # Allow RSpec to continue
      Thread.new { @bot.run }
    else
      @bot.run
    end
  end

  # @private
  # Allow IRB to be not-blocked by ESM's main thread
  def self.console!
    @console = true
  end

  # Borrowed from Rails
  # https://github.com/rails/rails/blob/master/railties/lib/rails.rb:72
  def self.env
    @env ||= ActiveSupport::StringInquirer.new(ENV["ESM_ENV"].presence || "development")
  end

  def self.load_config
    config = YAML.safe_load(ERB.new(File.read(File.expand_path("config/config.yml"))).result, aliases: true)[env]
    @config = JSON.parse(config.to_json, object_class: OpenStruct)
  end

  def self.initialize_steam
    SteamWebApi.configure do |config|
      config.api_key = @config.steam_api_key
    end
  end

  def self.initialize_logger
    @logger = Logger.new("logs/#{env}.log")

    @logger.formatter = proc do |severity, datetime, progname = "N/A", msg|
      message = "#{severity} [#{datetime.strftime("%F %H:%M:%S:%L")}] (#{progname})\n\t#{msg.to_s.gsub("\n", "\n\t")}\n\n"
      puts message if ENV["PRINT_LOG"] == "true"
      message
    end
  end

  def self.initialize_encryption
    SymmetricEncryption.load!('config/symmetric-encryption.yml', env)
  end
end
