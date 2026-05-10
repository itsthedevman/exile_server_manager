# frozen_string_literal: true

module ESM
  module Connection
    class Server
      class << self
        delegate :pause, :resume, to: :instance
      end

      def pause
        info!(state: :pausing)

        @server.block!
        @connection_manager.disconnect_all

        info!(state: :paused)
      end

      def resume
        info!(state: :resuming)

        @connection_manager.disconnect_all
        @server.unblock!

        info!(state: :resumed)
      end
    end
  end
end
