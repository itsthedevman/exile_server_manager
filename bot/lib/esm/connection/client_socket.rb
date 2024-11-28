# frozen_string_literal: true

module ESM
  module Connection
    class ClientSocket < Socket
      def address
        local_address.inspect_sockaddr
      end

      def read
        return unless readable?

        data = recv_nonblock(READ_BYTES)

        Base64.strict_decode64(data)
      rescue => e
        error!(error: e)
        nil
      end

      def write(data)
        raise TypeError, "Expected String, got #{data.class}" unless data.is_a?(String)
        return unless writeable?

        # Encode
        data = Base64.strict_encode64(data)

        # Send
        __getobj__.send(data, 0)
      rescue TypeError
        raise
      rescue Errno::EPIPE
        close
      rescue => e
        error!(error: e)
      end

      def close
        close_write if writeable?(0)
        close_read if readable?(0)
      end
    end
  end
end
