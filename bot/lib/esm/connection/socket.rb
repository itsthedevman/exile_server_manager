# frozen_string_literal: true

module ESM
  module Connection
    class Socket
      def initialize(socket)
        @socket = socket
      end

      def close
        @socket.close
      end

      def readable?(timeout = 5)
        wait_readable(timeout).first.size > 0
      end

      def writeable?(timeout = 5)
        wait_writeable(timeout).second.size > 0
      end

      private

      #
      # Blocks until the socket is readable
      #
      # @param timeout [Integer] Timeout in seconds
      #
      # @returns [Array] The sockets grouped by state [readable, writeable, errored]
      #
      def wait_readable(timeout = 5)
        IO.select([@socket], nil, nil, timeout) || [[], [], []]
      rescue IOError
        [[], [], []]
      end

      #
      # Blocks until the socket is writeable
      #
      # @param timeout [Integer] Timeout in seconds
      #
      # @returns [Array] The sockets grouped by state [readable, writeable, errored]
      #
      def wait_writeable(timeout = 5)
        IO.select(nil, [@socket], nil, timeout) || [[], [], []]
      rescue IOError
        [[], [], []]
      end
    end
  end
end
