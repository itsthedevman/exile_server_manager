# frozen_string_literal: true

module ESM
  module Connection
    class Server
      def pause
        @server.block!

        @connection_manager.disconnect_all
      end

      def resume
        @connection_manager.disconnect_all

        @server.unblock!
      end
    end
  end
end
