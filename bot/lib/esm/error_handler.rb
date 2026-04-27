# frozen_string_literal: true

module ESM
  # Used primarily as an observer for Concurrent::TimerTask
  class ErrorHandler
    def update(_time, _result, error)
      return if error.nil?

      error!(error:)
    end
  end
end
