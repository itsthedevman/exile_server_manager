# frozen_string_literal: true

module ESM
  module Connection
    class Socket < SimpleDelegator
      READ_BYTES = 65_444 - 20 - 8

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
        IO.select([__getobj__], nil, nil, timeout) || [[], [], []]
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
        IO.select(nil, [__getobj__], nil, timeout) || [[], [], []]
      rescue IOError
        [[], [], []]
      end
    end
  end
end
