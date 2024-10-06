# frozen_string_literal: true

module ESM
  module Connection
    class Client
      include Lifecycle

      Metadata = ImmutableStruct.define(:vg_enabled, :vg_max_sizes)

      attr_reader :public_id, :server_id, :connected_at

      delegate :address, to: :@socket

      def initialize(tcp_client)
        @socket = ClientSocket.new(tcp_client)
        @ledger = Ledger.new
        @config = ESM.config.connection_client

        @public_id = nil
        @server_id = nil

        @thread_pool = Concurrent::CachedThreadPool.new
        set_metadata(vg_enabled: false, vg_max_sizes: 0)

        execution_interval = @config.request_check
        @task = Concurrent::TimerTask.execute(execution_interval:) { on_message }
        @task.add_observer(ErrorHandler.new)

        @connected_at = Time.current
        info!(address:, state: :on_connect)
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end

      def close
        @task.shutdown
        @socket.close
        ESM.connection_server.on_disconnect(self)

        on_disconnect
      end

      def send_message(message, **)
        send_request(message, type: :message, **)
      end

      def send_error(content, block: false)
        message = ESM::Message.new.add_error(:message, content)
        send_request(message, type: :error, block:)
      end

      #
      # Sends a request over the network to the client
      #
      # @param message [ESM::Message, nil] The data to send
      # @param type [Symbol] The type of request. See ESM::Connection::Request::TYPES
      # @param block [true/false] Cause this method to block the current thread and either
      #   1. Until the request is responded to by the client
      #   2. The timeout is reached. This will raise ESM::Exception::RejectedPromise
      # @param timeout [Integer] A number in seconds on how long the process will block before
      #   considering a message to be timed out. Defaults to response_timeout in config.yml
      #
      # @return [ESM::Connection::Promise, ESM::Message]
      #   If block is false, a promise in an processing status is returned
      #   If block is true, the response as ESM::Message is returned
      #
      # @raises ESM::Exception::RejectedPromise, ESM::Exception::ExtensionError
      #
      def send_request(message = nil, type:, block: true, timeout: @config.response_timeout)
        # I feel so dirty. Multiline unless statements *shudder*
        unless message.nil? || message.is_a?(ESM::Message)
          raise TypeError, "Expected ESM::Message or nil. Got #{message.class}"
        end

        info!(
          address:,
          public_id:,
          server_id:,
          outbound: {type:, content: message&.to_h}
        )

        id = message&.id
        content = message&.to_s

        # Send the data over the network
        promise = write(id:, type:, content:)
        return promise.execute unless block

        # Block and wait for a response or timeout
        response = promise.wait_for_response(timeout)
        raise response.reason if response.rejected?

        response_message = ESM::Message.from_string(response.value)
        response_message.set_metadata(server_id:)

        info!(address:, public_id:, server_id:, inbound: response_message.to_h)

        # Messages with errors do not contain any extra data or metadata
        # Merge the errors from the response into the original message and use that
        # to build the error messages (the error message can reference data/metadata)
        if response_message.errors?
          message.add_errors(response_message.errors.map(&:to_h))
          embed = ESM::Embed.build(:error, description: message.error_messages.join("\n"))

          raise ESM::Exception::ExtensionError, embed
        end

        response_message
      end

      #
      # Lower level method to send a request to the client and either disregard the response or block (default)
      #
      # @see #send_request or #send_message for higher level methods
      #
      # @param id [String, nil] A UUID, if any, that will be used to differentiate this request
      # @param type [Symbol] The request type.
      #     See ESM::Connection::Client::Request::TYPES for full list
      # @param content [Symbol, Array<Numeric>, nil, #bytes] The content to send in the request
      # @param block [true, false] Should this method block and wait for the response?
      #
      # @return [ESM::Connection::Client::Promise]
      #
      def write(type:, id: nil, content: nil)
        request = Request.new(id:, type:, content:)

        # Adding the request to the ledger allows us to track the request across multiple threads
        # ensuring the response to passed back to the blocking thread
        promise = @ledger.add(request)

        # All data passed is in JSON format
        # ESM will never be huge to the point where JSON is a limitation so this
        # isn't a concern of mine
        content = request.to_json

        # Compress
        content = ActiveSupport::Gzip.compress(content)

        # Encrypt
        content = @encryption.encrypt(content)

        # Once the promise is executed, write the content to the client
        promise.then { @socket.write(content) }
      end

      private

      def read
        data = @socket.read
        return if data.blank?

        # The first data we receive should be the identification (when @id is nil)
        # Every request from that point on will be encrypted
        data =
          if @public_id.nil?
            data
          else
            @encryption.decrypt(data)
          end

        # Decompress
        data = ActiveSupport::Gzip.decompress(data)

        data = ESM::JSON.parse(data)
        return if data.blank?

        Request.from_client(data)
      end
    end
  end
end
