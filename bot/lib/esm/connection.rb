# frozen_string_literal: true

module ESM
  class Connection
    attr_reader :server, :version, :tcp_server

    # @return [Boolean] Returns true the connection has been initialized and is ready for use
    attr_accessor :initialized

    def initialize(tcp_server, server_uuid)
      @tcp_server = tcp_server
      @server = ESM::Server.find_by_uuid(server_uuid)
    end

    delegate :uuid, :server_id, to: :@server

    # @param message [Hash, ESM::Message] This can be either a hash of arguments for ESM::Message, or an instance of it.
    def send_message(message = nil, opts = {})
      message = ESM::Message.from_hash(message) if message.is_a?(Hash)

      @tcp_server.fire(message, to: uuid, **opts)
    end

    def on_open(message)
      @version = Semantic::Version.new(message.data.extension_version)
      ESM::Event::ServerInitialization.new(self, message).run!
    end

    def on_message(incoming_message, outgoing_message)
      @server.reload # Ensure the server is up-to-date

      case incoming_message.type
      when ->(type) { type == "event" && incoming_message.data_type != "empty" }
        on_event(incoming_message, outgoing_message)
      else
        outgoing_message&.on_response(incoming_message)
      end
    end

    def on_close
      @server.metadata.clear!
    end

    def on_event(incoming_message, _outgoing_message)
      case incoming_message.data_type
      when "send_to_channel"
        ESM::Event::SendToChannel.new(self, incoming_message).run!
      else
        raise "[#{incoming_message.id}] Connection#on_event does not implement this type: \"#{incoming_message.data_type}\""
      end
    end
  end
end
