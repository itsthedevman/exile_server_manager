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
      end

      def send_message(message, **)
        send_request(message, type: :message, **)
      end

      def send_error(error, block: false)
        send_request(error, type: :error, block:)
      end

      def send_request(content = nil, type:, block: true)
        info!(
          address:,
          public_id:,
          server_id:,
          outbound: {type:, content: content.respond_to?(:to_h) ? content.to_h : content}
        )

        promise = write(
          id: (content.respond_to?(:id) ? content.id : nil),
          type:,
          content: content.to_s
        )

        return promise.execute unless block

        response = promise.wait_for_response(@config.response_timeout)
        raise ESM::Exception::RejectedPromise, response.reason if response.rejected?

        message = ESM::Message.from_string(response.value)
        message.set_metadata(server_id:)

        info!(address:, public_id:, server_id:, inbound: message.to_h)

        if message.errors?
          embed = ESM::Embed.build(:error, description: message.error_messages.join("\n"))
          raise ESM::Exception::ExtensionError, embed
        end

        message
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
