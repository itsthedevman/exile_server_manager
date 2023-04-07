# frozen_string_literal: true

module ESM
  class Connection
    class Server
      ################################
      # Class methods
      ################################

      class << self
        attr_reader :instance

        delegate :disconnect_all!, :pause, :resume, to: :@instance, allow_nil: true

        def run!
          @instance = new
        end

        def stop!
          return true if @instance.nil?

          @instance.stop
          @instance = nil
        end

        def connection(server_uuid)
          return if @instance.nil?

          @instance.connections[server_uuid]
        end
      end

      ################################
      # Instance methods
      ################################

      attr_reader :server, :connections, :message_overseer

      def initialize
        @connections = {} # By server_uuid
        @mutex = Mutex.new
        @redis = Redis.new(ESM::REDIS_OPTS)
        @message_overseer = ESM::Connection::MessageOverseer.new
        @state = :resumed

        @redis.del("bot_outbound")
        @redis.del("bot_inbound")

        self.tcp_server_alive = false
        self.server_ping_received = false
        refresh_keys
        health_check
        delegate_inbound_messages
        process_inbound_messages

        info!(status: "Started")
      end

      def stop
        # Kill the processing threads
        [
          @thread_delegate_inbound_messages,
          @thread_process_inbound_messages,
          @thread_health_check
        ].each { |id| Thread.kill(id) }

        @message_overseer.remove_all!(with_error: true)
        disconnect_all!

        # Close the connection to redis
        @redis.close
        @redis_process_inbound_messages.close
        @redis_delegate_inbound_messages.close

        true
      end

      def resume
        return if @state == :resumed

        __send_internal({type: :server_request, content: {type: :resume}})
        @state = :resumed
      end

      def pause
        return if @state == :paused

        __send_internal({type: :server_request, content: {type: :pause}})

        @state = :paused
      end

      def disconnect_all!
        __send_internal({type: :server_request, content: {type: :disconnect}})
      end

      def tcp_server_alive?
        @mutex.synchronize { @tcp_server_alive }
      end

      #
      # Sends a message to a client (a3 server)
      #
      # @param message [ESM::Message] The message to send
      # @param to [String] The UUID of the server to send the message to
      # @param forget [Boolean] By default (true), the message will be sent asynchronously. Set to false to synchronously send the message. The response message (if any) will be returned from this message
      #
      # @return [ESM::Message] If forget is false, this will be the incoming message containing the response. Otherwise, it will be the outgoing message
      #
      def fire(message, to:, forget: true)
        raise ESM::Exception::ServerNotConnected if !tcp_server_alive?
        raise ESM::Exception::CheckFailureNoMessage if !message.is_a?(ESM::Message)

        info!(
          send_opts: {forget: forget},
          server: to,
          message: message.to_h
        )

        # Watch the message to see if it's been acknowledged or responded to.
        message.synchronous unless forget

        @message_overseer.watch(message)

        ESM::Test.outbound_server_messages.store(message, to) if ESM.env.test?

        unless ESM.env.test? && ESM::Test.block_outbound_messages
          __send_internal({type: :send_to_client, content: {server_uuid: to, message: message.to_h(for_arma: true)}})
        end

        return message if forget

        message.wait_for_response
      end

      private

      def __send_internal(request)
        @redis.rpush("bot_outbound", request.to_json)
      end

      # Store all of the server_uuids and their keys in redis.
      # This will allow the TCPServer to quickly pull a key by a server_uuid to decrypt messages
      def refresh_keys
        @redis.del("server_keys")

        server_keys = ESM::Server.all.pluck(:uuid, :server_key)
        return if server_keys.blank?

        # Store the data in Redis
        @redis.hmset("server_keys", *server_keys)
      end

      def delegate_inbound_messages
        @redis_delegate_inbound_messages = Redis.new(ESM::REDIS_OPTS)

        @thread_delegate_inbound_messages =
          Thread.new do
            loop do
              @redis_delegate_inbound_messages.blmove("server_outbound", "bot_inbound", "LEFT", "RIGHT")
            end
          end
      end

      def process_inbound_messages
        @redis_process_inbound_messages = Redis.new(ESM::REDIS_OPTS)

        @thread_process_inbound_messages =
          Thread.new do
            loop do
              _name, json = @redis_process_inbound_messages.blpop("bot_inbound")
              Thread.new { process_inbound_request(json) }
            end
          end
      end

      def health_check
        @thread_health_check =
          Thread.new do
            self.server_ping_received = false

            currently_alive = false
            100.times do
              break currently_alive = true if server_ping_received?

              sleep(0.01)
            end

            # Only set the value if it differs
            previously_alive = tcp_server_alive?
            next if currently_alive == previously_alive

            self.tcp_server_alive = currently_alive

            if tcp_server_alive?
              info!(server_status: "Connected")
            else
              error!(server_status: "Disconnected")
            end
          end
      end

      def server_ping_received?
        @mutex.synchronize { @server_ping_received }
      end

      def server_ping_received=(value)
        @mutex.synchronize { @server_ping_received = value }
      end

      def tcp_server_alive=(value)
        @mutex.synchronize { @tcp_server_alive = value }
      end

      def process_inbound_request(json)
        request = json.to_h

        case request[:type]
        when "ping"
          on_ping
        when "disconnected"
          on_disconnect(request)
        when "inbound"
          on_inbound(request)
        end
      end

      def on_inbound(request)
        request = request[:content].to_h

        server_uuid = request[:server_uuid]
        message = ESM::Message.from_hash(request[:message])

        case message.data_type
        when :init
          on_connect(server_uuid, message)
        else
          on_message(server_uuid, message)
        end

        ESM::Test.inbound_server_messages.store(message, server_uuid) if ESM.env.test?
      rescue => e
        uuid = SecureRandom.uuid
        error!(error: e, id: uuid, message_id: message&.id)

        # Prevents getting stuck in a error reporting loop
        if message && !message.errors?
          # Reply back to the message
          message = ESM::Message.event
            .set_id(message.id)
            .add_error("message", I18n.t("exceptions.system", error_code: uuid))

          fire(message, to: server_uuid, forget: true)
        end
      end

      def on_connect(server_uuid, message)
        info!(server_uuid: server_uuid, incoming_message: message.to_h)

        connection = ESM::Connection.new(self, server_uuid)

        return error!(error: "Server does not exist", uuid: server_uuid) if connection.server.nil?
        return connection.server.community.log_event(:error, message.errors.join("\n")) if message.errors?

        @connections[server_uuid] = connection
        connection.on_open(message)
      end

      def on_message(server_uuid, incoming_message)
        # Retrieve the original message. If it's nil, the message originated from the client
        outgoing_message = @message_overseer.retrieve(incoming_message.id)

        info!(
          outgoing_message: outgoing_message&.to_h,
          incoming_message: incoming_message.to_h
        )

        # Handle any errors
        if incoming_message.errors?
          outgoing_message&.on_error(incoming_message)
          return
        end

        connection = @connections[server_uuid]
        connection&.on_message(incoming_message, outgoing_message)
      end

      def on_disconnect(request)
        server_uuid = request[:content]
        info!(server_uuid: server_uuid)

        connection = @connections.delete(server_uuid)
        return if connection.nil?

        connection.on_close
      end

      def on_ping
        self.server_ping_received = true

        @thread_health_check.join
        health_check

        __send_internal({type: "pong"})
      end
    end
  end
end
