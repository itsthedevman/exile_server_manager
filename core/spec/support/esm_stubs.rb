# frozen_string_literal: true

# Stub ESM module methods that are expected to be provided by consuming applications
module ESM
  class << self
    def env
      "test"
    end

    def config
      @config ||= Struct.new(:print_to_stdout).new(false)
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= ActiveSupport::BacktraceCleaner.new
    end
  end
end
