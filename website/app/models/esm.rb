# frozen_string_literal: true

module ESM
  class << self
    def bot
      Bot
    end

    def env
      Rails.env
    end

    def config
      {print_to_stdout: true}.to_struct
    end

    def backtrace_cleaner
      Rails.backtrace_cleaner
    end
  end
end
