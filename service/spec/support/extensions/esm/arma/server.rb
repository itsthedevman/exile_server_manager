# frozen_string_literal: true

module ESM
  module Arma
    class Server
      class << self
        delegate :pause, :resume, to: :instance
      end

      def pause
        trace!(state: :pausing)

        @server.block!
        @connection_manager.disconnect_all

        trace!(state: :paused)
      end

      def resume
        trace!(state: :resuming)

        @connection_manager.disconnect_all
        @server.unblock!

        trace!(state: :resumed)
      end
    end
  end
end
