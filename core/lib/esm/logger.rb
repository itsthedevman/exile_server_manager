# frozen_string_literal: true

module ESM
  class Logger < ::Logger
    SEVERITIES = [:trace, :debug, :info, :warn, :error].freeze

    def self.define_global_methods!
      SEVERITIES.each do |severity|
        Kernel.module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{severity}!(content = {})
            return unless ESM.logger.#{severity}?

            caller_label = ESM.logger.format_caller(caller_locations(1, 1).first)
            ESM.logger.#{severity}(caller_label) { ESM.logger.format_content(content) }
          end
        RUBY
      end
    end

    ####################################################################################################################

    def initialize(...)
      super

      self.formatter = lambda do |severity, datetime, progname, message|
        header = "#{severity} [#{datetime.utc.strftime("%F %H:%M:%S:%L")}]"
        header += " (#{progname})" if progname.present?
        body = "\n\t#{message.to_s.gsub("\n", "\n\t")}\n\n"

        if ESM.config.print_to_stdout
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
    end

    def format_content(content)
      if content.is_a?(Hash) && (error = content[:error]) && error.is_a?(StandardError)
        content[:error] = {
          class: error.class,
          message: error.message,
          backtrace: ESM.backtrace_cleaner.clean(error.backtrace)
        }
      end

      if content.is_a?(Hash)
        ESM::JSON.pretty_generate(content).presence || ""
      else
        content || ""
      end
    end

    def format_caller(caller)
      caller_label = caller.label.gsub("block in ", "")

      "[line:#{caller.lineno}]#{caller_label}"
    end

    ####################################################################################################################

    SEVERITIES.each do |severity|
      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{severity}!(content = {})
          caller_label = format_caller(caller_locations(1, 1).first)
          #{severity}(caller_label) { format_content(content) }
        end
      RUBY
    end
  end
end
