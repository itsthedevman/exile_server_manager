# frozen_string_literal: true

#
# Welcome to Exile Server Manager!
#
# I hope you enjoy your stay.
#

[
  # This contains a check for the existence of the Rails class.
  # One of the action/active gems defines Rails, so this needs to be loaded first
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
  "discordrb",
  "dotenv",
  "dotiw",
  "drb",
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
  "steam-condenser",
  "terminal-table",
  "yaml",
  "zeitwerk"
].each { |gem| require gem }

ESM_ROOT_PATH = Pathname.new(File.expand_path("..", ".")).freeze
ESM_BOT_PATH = Pathname.new(File.expand_path(".")).freeze
ESM_CORE_PATH = ESM_ROOT_PATH.join("core").freeze

#############################
# Pre init

Dir[ESM_BOT_PATH.join("lib", "pre_init", "*.rb")].sort.each { |f| require f }

#############################
# Load ESM

# TODO: Docs
module ESM
  # TODO: Docs
  REDIS_OPTS = {
    host: ENV.fetch("REDIS_HOST", "localhost"),
    reconnect_attempts: 10
  }.freeze

  class << self
    # TODO: Docs
    def discord_bot
      @discord_bot ||= ESM::Discord::Bot.new
    end

    # TODO: Docs
    def run!(async: false, **)
      trace!("Trace logging enabled")
      debug!("Debug logging enabled")

      info!("Starting Exile Server Manager...")

      load! unless loader.setup? && loader.eager_loaded?

      # Load any model overwrites
      Dir[ESM_CORE_PATH.join("lib", "esm", "models", "*.rb")]
        .map { |path| File.basename(path, "*.rb") }
        .map { |filename| root.join("lib", "esm", "model", filename) }
        .select(&:exist?)
        .each { |path| load path }

      if env.development?
        server = Server.all.first
        redis.set("server_key", server.token.to_json) if server
      end

      API.run

      discord_bot.run(async:, **)
    end

    # TODO: Docs
    def load!
      loader.setup
      loader.eager_load
    end

    # TODO: Docs
    def root
      @root ||= ESM_BOT_PATH
    end

    # TODO: Docs
    def redis
      @redis ||= ConnectionPool::Wrapper.new do
        Redis.new(**REDIS_OPTS)
      end
    end

    # TODO: Docs
    def cache
      @cache ||= ActiveSupport::Cache::RedisCacheStore.new(namespace: "esm_bot", redis: redis)
    end

    # TODO: Docs
    def env
      @env ||= Inquirer.new(:production, :staging, :test, :development).set(ENV["ESM_ENV"].presence || :development)
    end

    # TODO: Docs
    def config
      @config ||= begin
        config = YAML.safe_load(
          ERB.new(File.read(File.expand_path("config/config.yml"))).result,
          aliases: true
        )[env.to_s]

        config.to_struct
      end
    end

    # TODO: Docs
    def loader
      @loader ||= begin
        Zeitwerk::Loader.attr_predicate(:setup, :eager_loaded)
        Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      end
    end

    # TODO: Docs
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

#############################
# Post init

Dir[ESM_BOT_PATH.join("lib", "post_init", "*.rb")].sort.each { |f| require f }
