# frozen_string_literal: true

module ESM
  module Connection
    class ClientSocket < Socket
      HEADER_SIZE = 4.bytes
      MAX_READ = 16.megabytes

      def read
        return unless readable?

        length_bytes = @socket.read(HEADER_SIZE)
        return if length_bytes.blank?

        length = length_bytes.unpack1("N")
        raise Exception::MessageTooLarge, length if length >= MAX_READ

        data = @socket.read(length)
        Base64.strict_decode64(data)
      rescue IOError => e
        return if ignored_io_error?(e)

        raise # Re-raise
      rescue => e
        error!(address:, error: e)
        nil
      end

      def write(data)
        raise TypeError, "Expected String, got #{data.class}" unless data.is_a?(String)
        return unless writeable?

        # Encode
        data = Base64.strict_encode64(data)

        # Send
        @socket.write(data)
      rescue TypeError
        raise
      rescue Errno::EPIPE
        close
      rescue => e
        error!(error: e)
      end
    end
  end
end
