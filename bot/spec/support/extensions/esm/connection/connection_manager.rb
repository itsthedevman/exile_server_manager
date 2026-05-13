# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def disconnect_all
        # Snapshot the collections BEFORE iterating - Client#close calls
        # ConnectionManager#on_disconnect which mutates these via
        # `@lobby.delete` / `@connections.delete`. Iterating over the
        # live collections while close mutates them either raises
        # mid-iteration (leaving the rest of `pause` un-executed) or
        # silently skips remaining clients, both of which leave Arma
        # without the FIN it needs to notice the bot has gone away.
        #
        # `.dup` is defensive against the Concurrent collections
        # returning live views; we want a true frozen-in-time list.
        lobby_clients = @lobby.to_a.dup
        connection_clients = @connections.values.dup

        if lobby_clients.any? || connection_clients.any?
          info!(
            state: :disconnect_all,
            lobby_size: lobby_clients.size,
            connection_count: connection_clients.size
          )
        end

        # Isolate per-client failures so one bad close cannot strand
        # others with an open socket.
        lobby_clients.each { |client| safely_close(client, from: :lobby) }
        connection_clients.each { |client| safely_close(client, from: :connections) }

        @lobby.clear
        @connections.clear
      end

      private

      def safely_close(client, from:)
        client.close
      rescue => e
        error!(
          state: :close_failed,
          from:,
          address: client&.address,
          public_id: client&.public_id,
          error: e
        )
      end
    end
  end
end
