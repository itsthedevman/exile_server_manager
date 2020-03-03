# frozen_string_literal: true

# Sends Ping requests to all connected servers to ensure they are still alive
module ESM
  class Websocket
    class ConnectionWatcher
      def self.start!
        @thread = Thread.new do
          loop do
            check_connections
            sleep(30)
          end
        end
      end

      # Checks all the connections
      # @private
      def self.check_connections
        ESM::Websocket.connections.each(&method(:process_connection))
      end

      # Sends a ping request
      # @private
      def self.process_connection(_server_id, wsc)
        wsc.connection.ping("Are you still there?")
      end

      def self.stop!
        return if @thread.nil?

        Thread.kill(@thread)
      end
    end
  end
end
