# frozen_string_literal: true

module ESM
  class << self
    attr_reader :bot, :config, :logger
  end

  def self.run!
    # Load our Config
    @config = load_config

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
    JSON.parse(config.to_json, object_class: OpenStruct)
  end

  def self.initialize_steam
    SteamWebApi.configure do |config|
      config.api_key = @config.steam_api_key
    end
  end

  def self.initialize_logger
    @logger = Logger.new("logs/#{env}.log")

    @logger.formatter = proc do |severity, datetime, progname = "N/A", msg|
      "#{severity} [#{datetime.strftime("%F %H:%M:%S:%L")}] (#{progname})\n\t#{msg.to_s.gsub("\n", "\n\t")}\n\n"
    end
  end

  def self.initialize_encryption
    SymmetricEncryption.load!('config/symmetric-encryption.yml', env)
  end
end
