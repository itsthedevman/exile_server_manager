# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def initialize(lobby_timeout, execution_interval: 1)
        @lobby_timeout = lobby_timeout

        @connections = Concurrent::Map.new
        @lobby = Concurrent::Array.new
        @task = Concurrent::TimerTask.execute(execution_interval:) { check_lobby }
        @task.add_observer(ErrorHandler.new)
      end

      def find(id)
        @connections[id]
      end

      def on_connect(socket)
        @lobby << Client.new(socket)
      end

      def on_initialize(client)
        @lobby.delete(client)
        @connections[client.public_id] = client
      end

      def on_disconnect(client)
        @lobby.delete(client)
        @connections.delete(client.public_id)
      end

      private

      # Traverse the array without holding onto its mutex
      def check_lobby
        client = @lobby.shift
        return if client.nil?

        timed_out = (Time.current - client.connected_at) >= @lobby_timeout

        # Hasn't timed out yet, add it back to the top of the array
        return @lobby << client unless timed_out

        client.close
      end
    end
  end
end
