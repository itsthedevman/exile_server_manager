# frozen_string_literal: true

module ESM
  module Arma
    class ServerSocket < Socket
      def accept
        return unless readable?

        @socket.accept
      rescue => e
        error!(error: e)
      end
    end
  end
end
