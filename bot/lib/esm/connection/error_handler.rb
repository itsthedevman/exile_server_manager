# frozen_string_literal: true

module ESM
  module Connection
    # Used primarily as an observer for Server and Client tasks
    class ErrorHandler
      def update(_time, _result, error)
        return if error.nil?

        error!(error:)
      end
    end
  end
end
