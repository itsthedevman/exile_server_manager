# frozen_string_literal: true

# Welcome to Exile Server Manager!
#   I hope you enjoy your stay.
#
# Just fyi, this file is laid out in a particular order so
#   I can access ESM.env and ESM.config when all other files load

[
  # This contains a check for the existence of the Rails class.
  # One of the action/active gems defines Rails, so this needs to be loaded first
  "sucker_punch",

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
  "steam_web_api",
  "steam-condenser",
  "terminal-table",
  "yaml",
  "zeitwerk"
].each { |gem| require gem }

#############################
# Load extensions and other useful classes to have
Dir["#{__dir__}/esm/extension/**/*.rb"].sort.each { |extension| require extension }

require "otr-activerecord" if ENV["ESM_ENV"] != "production"

# Load Dotenv variables; overwriting any that already exist
Dotenv.overload
Dotenv.overload(".env.test") if ENV["ESM_ENV"] == "test"
Dotenv.overload(".env.prod") if ENV["ESM_ENV"] == "production"

# Default timezone to UTC
Time.zone_default = Time.find_zone!("UTC")

#################################
# Logging methods!
#################################
[:trace, :debug, :info, :warn, :error].each do |severity|
  define_method(:"#{severity}!") do |content = {}|
    __log(severity, caller_locations(1, 1).first, content)
  end
end

# Used internally by logging methods. Do not call manually
def __log(severity, caller_data, content)
  if content.is_a?(Hash) && content[:error].is_a?(StandardError)
    e = content[:error]

    content[:error] = {
      class: e.class,
      message: e.message,
      backtrace: ESM.backtrace_cleaner.clean(e.backtrace)
    }
  end

  caller_class = caller_data
    .path
    .sub("#{__dir__}/", "")
    .sub(".rb", "")
    .classify

  caller_method = caller_data.label.gsub("block in ", "")

  ESM.logger.send(severity, "#{caller_class}##{caller_method}:#{caller_data.lineno}") do
    if content.is_a?(Hash)
      ESM::JSON.pretty_generate(content).presence || ""
    else
      content || ""
    end
  end
end
#################################

module ESM
  REDIS_OPTS = {
    host: ENV.fetch("REDIS_HOST", "localhost"),
    reconnect_attempts: 10
  }.freeze

  class << self
    def bot
      @bot ||= ESM::Bot.new
    end

    def run!(async: false, **)
      require_relative "post_init"

      # Start the bot
      bot.run(async:, **)
    end

    # Load everything right meow
    def load!
      loader.setup
      loader.eager_load
    end

    def root
      @root ||= Pathname.new(File.expand_path("."))
    end

    def logger
      @logger ||= begin
        logger = Logger.new("log/#{env}.log", "daily")
        logger.level = Logger::INFO

        logger.formatter = proc do |severity, datetime, progname = "N/A", msg|
          header = "#{severity} [#{datetime.utc.strftime("%F %H:%M:%S:%L")}] (#{progname})"
          body = "\n\t#{msg.to_s.gsub("\n", "\n\t")}\n\n"

          if config.print_to_stdout
            styled_header =
              case severity
              when "TRACE"
                header.colorize(:cyan)
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

            styled_body =
              case severity
              when "WARN"
                body.colorize(:yellow)
              when "ERROR", "FATAL"
                body.colorize(:red)
              else
                body
              end

            puts "#{styled_header}#{styled_body}" # rubocop:disable Rails/Output
          end

          "#{header}#{body}"
        end

        logger
      end
    end

    def redis
      @redis ||= ConnectionPool::Wrapper.new do
        Redis.new(**REDIS_OPTS)
      end
    end

    def cache
      @cache ||= ActiveSupport::Cache::RedisCacheStore.new(namespace: "esm_bot", redis: redis)
    end

    def env
      @env ||= Inquirer.new(:production, :staging, :test, :development).set(ENV["ESM_ENV"].presence || :development)
    end

    def config
      @config ||= begin
        config = YAML.safe_load(
          ERB.new(File.read(File.expand_path("config/config.yml"))).result,
          aliases: true
        )[env.to_s]

        config.to_struct
      end
    end

    def loader
      @loader ||= begin
        Zeitwerk::Loader.attr_predicate(:setup, :eager_loaded)
        Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      end
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= begin
        cleaner = ActiveSupport::BacktraceCleaner.new
        cleaner.add_filter { |line| line.gsub(root.to_s, "") }
        cleaner.add_silencer { |line| /\/ruby.gems/.match?(line) }
        cleaner
      end
    end

    #
    # Handles the connection between the bot and all of the A3 servers
    #
    def connection_server
      @connection_server ||= ESM::Connection::Server.new
    end
  end
end

# Required ahead of time, ignored in autoloader
require_relative "esm/database"
ESM::Database.connect!

# Run pre_init (Throwback to Exile)
require_relative "pre_init"
require_relative "pre_init_dev" if ESM.env.development?
