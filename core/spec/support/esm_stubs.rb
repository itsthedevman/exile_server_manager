# frozen_string_literal: true

# Stub ESM module methods that are expected to be provided by consuming applications
module ESM
  class Environment
    def initialize(name)
      @name = name
    end

    def production?
      @name == "production"
    end

    def development?
      @name == "development"
    end

    def test?
      @name == "test"
    end

    def to_s
      @name
    end
  end

  class << self
    def env
      @env ||= Environment.new("test")
    end

    def config
      @config ||= Struct.new(:print_to_stdout).new(false)
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= ActiveSupport::BacktraceCleaner.new
    end
  end
end
