# frozen_string_literal: true

module ESM
  module Arma
    class ConnectionManager
      def initialize(lobby_timeout: 3, heartbeat_timeout: 3, execution_interval: 0.5)
        @lobby_timeout = lobby_timeout
        @heartbeat_timeout = heartbeat_timeout

        @lobby = Concurrent::Array.new
        @ids_to_check = Concurrent::Array.new
        @connections = Concurrent::Map.new
        @pool = Concurrent::CachedThreadPool.new

        @lobby_task = TimerTask.execute(execution_interval:) { check_lobby }
        @heartbeat = TimerTask.execute(execution_interval:) { check_connections }
      end

      def stop
        info!(
          state: :stopping,
          lobby_size: @lobby.size,
          connection_size: @connections.size
        )

        @lobby_task.shutdown
        @heartbeat.shutdown

        @connections.each { |_public_id, client| client.close }
        @lobby.each { |client| client.close }
      end

      def find(id)
        @connections[id]
      end

      def on_connect(socket)
        client = Client.new(socket)
        @lobby << client

        info!(
          state: :lobby_admitted,
          address: client.address,
          lobby_size: @lobby.size
        )
      end

      def on_initialize(client)
        @ids_to_check << client.public_id

        @lobby.delete(client)
        @connections[client.public_id] = client

        info!(
          state: :authenticated,
          address: client.address,
          public_id: client.public_id,
          server_id: client.server_id,
          lobby_size: @lobby.size,
          connection_size: @connections.size
        )
      end

      def on_disconnect(client)
        @ids_to_check.delete(client.public_id)

        in_lobby = @lobby.delete(client)
        was_connected = !@connections.delete(client.public_id).nil?

        from =
          if in_lobby
            :lobby
          elsif was_connected
            :connections
          else
            :untracked
          end

        info!(
          state: :removed,
          address: client.address,
          public_id: client.public_id,
          server_id: client.server_id,
          from:,
          lobby_size: @lobby.size,
          connection_size: @connections.size
        )
      end

      private

      # Traverse the array without holding onto its mutex
      def check_lobby
        client = @lobby.shift
        return if client.nil?

        timed_out = (Time.current - client.connected_at) >= @lobby_timeout

        # Hasn't timed out yet, add it back to the top of the array
        return @lobby << client unless timed_out

        info!(
          state: :lobby_timeout,
          address: client.address,
          age: Time.current - client.connected_at,
          timeout: @lobby_timeout
        )

        client.close
      end

      # Traverse the connections and ping them every so often to determine if they are
      # still connected or not by sending them a heartbeat request
      def check_connections
        id = @ids_to_check.shift
        return if id.nil?

        client = find(id)
        return if client.nil?
        return @ids_to_check << id if client.recent_heartbeat?

        trace!(
          state: :heartbeat_dispatch,
          public_id: id,
          server_id: client.server_id
        )

        @pool.post do
          response = client.write(type: :heartbeat).wait_for_response(@heartbeat_timeout)

          if response.fulfilled?
            client.update_last_heartbeat
            @ids_to_check << id

            return
          end

          warn!(
            state: :heartbeat_failed,
            public_id: id,
            server_id: client.server_id,
            timeout: @heartbeat_timeout,
            reason: response.reason
          )

          client.close
        end
      end
    end
  end
end
