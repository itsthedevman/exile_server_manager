# frozen_string_literal: true

require "colorize"
require "http"

module ESM
  class << self
    def logger
      @logger ||= begin
        logger = ESM::Logger.new("log/#{env}.log", "daily")

        logger.level =
          case env
          when "development", "test"
            Logger::DEBUG
          else
            Logger::INFO
          end

        logger
      end
    end

    def env
      raise "ESM.env - not implemented. Has ESM not been loaded?"
    end

    def config
      raise "ESM.config - not implemented. Has ESM not been loaded?"
    end

    def backtrace_cleaner
      raise "ESM.backtrace_cleaner - not implemented. Has ESM not been loaded?"
    end
  end
end
