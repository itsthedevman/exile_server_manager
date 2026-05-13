# frozen_string_literal: true

module ESM
  module Connection
    class ServerSocket < Socket
      def blocker
        @blocker ||= Concurrent::AtomicBoolean.new
      end

      def block!
        blocker.make_true
      end

      def unblock!
        blocker.make_false
      end

      alias_method :og_readable?, :readable?

      def readable?
        return if blocker.true?

        og_readable?
      end

      alias_method :og_accept, :accept

      # Two-stage block check: `readable?` is checked BEFORE the IO.select
      # inside `og_readable?` runs, but that IO.select can sit for up to 3
      # seconds waiting for a connection. If `block!` is called while the
      # select is in-flight, the select still returns truthy when a socket
      # arrives - and without this guard, we would admit a connection
      # while supposedly paused. Re-check `blocker` after `og_accept` and
      # close any socket that slipped through the race.
      def accept
        socket = og_accept
        return socket unless socket.is_a?(TCPSocket)

        if blocker.true?
          debug!(
            state: :accept_blocked,
            peer: socket.peeraddr(false)[2..3].join(":")
          )
          socket.close
          return nil
        end

        socket
      end
    end
  end
end
