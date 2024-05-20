# frozen_string_literal: true

module ESM
  module Connection
    class ServerSocket < Socket
      def accept
        return unless readable?

        __getobj__.accept_nonblock
      rescue IO::EAGAINWaitReadable
        # Noop - we'll try again next iteration
      rescue => e
        error!(error: e)
      end
    end
  end
end
