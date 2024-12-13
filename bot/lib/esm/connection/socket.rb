# frozen_string_literal: true

module ESM
  module Connection
    class Socket
      IGNORED_IO_ERRORS = [
        "closed stream",
        "stream closed in another thread",
        "uninitialized stream"
      ].freeze

      attr_reader :address

      delegate :close, to: :@socket

      def initialize(socket)
        @socket = socket
        @address = socket.local_address.inspect_sockaddr
      end

      def shutdown(...)
        @socket.shutdown(...)
      rescue IOError => e
        return if ignored_io_error?(e)
        raise
      end

      def close(...)
        @socket.close(...)
      rescue IOError => e
        return if ignored_io_error?(e)
        raise
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

      def ignored_io_error?(error)
        IGNORED_IO_ERRORS.include?(error.message)
      end
    end
  end
end
