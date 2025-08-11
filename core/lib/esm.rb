# frozen_string_literal: true

require "colorize"

module ESM
  class << self
    def logger
      @logger ||= begin
        logger = Logger.new("log/#{env}.log", "daily")

        logger.level =
          case env
          when "development", "test"
            Logger::DEBUG
          else
            Logger::INFO
          end

        logger.formatter = proc do |severity, datetime, progname = "N/A", msg|
          header = "#{severity} [#{datetime.utc.strftime("%F %H:%M:%S:%L")}]"
          header += " (#{progname})" if progname.present?
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

            puts "#{styled_header}#{styled_body}"
          end

          "#{header}#{body}"
        end

        logger
      end
    end

    def log!(lazy_debug = nil, trace: nil, debug: nil, info: nil, warn: nil, error: nil)
      caller_data = caller_locations(1, 1).first

      log_entry(:trace, caller_data, trace) if trace
      log_entry(:debug, caller_data, lazy_debug) if lazy_debug
      log_entry(:debug, caller_data, debug) if debug
      log_entry(:info, caller_data, info) if info
      log_entry(:warn, caller_data, warn) if warn
      log_entry(:error, caller_data, error) if error
    end

    def env
      raise "ESM.env - not implemented"
    end

    def config
      raise "ESM.config - not implemented"
    end

    def backtrace_cleaner
      raise "ESM.backtrace_cleaner - not implemented"
    end

    private

    def log_entry(severity, caller_data, content)
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

      logger.send(severity, "#{caller_class}##{caller_method}:#{caller_data.lineno}") do
        if content.is_a?(Hash)
          ESM::JSON.pretty_generate(content).presence || ""
        else
          content || ""
        end
      end
    end
  end
end
