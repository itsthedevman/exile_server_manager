# frozen_string_literal: true

module ESM
  class Websocket
    class Server
      def self.run
        # Load Faye support for puma
        Faye::WebSocket.load_adapter("puma")

        @server = Puma::Server.new(self, Puma::Events.strings)
        @server.add_tcp_listener("0.0.0.0", ENV["WEBSOCKET_PORT"])
        @server.run

        @overseer = ESM::Websocket::Connection::Overseer.new
      end

      def self.call(env)
        return if !Faye::WebSocket.websocket?(env)

        # Create a new websocket client
        ws = Faye::WebSocket.new(env)

        # To avoid over loading everything
        @overseer.add_to_lobby(ws)

        # Return async Rack response
        ws.rack_response
      end

      def self.log(*args)
        ESM.logger.info("#{self.class}##{__method__}") { "Websocket server is running on #{args.first}" }
      end

      def self.stop
        # Trigger a fake on_close event to notify communities that the connection lost is because ESM is rebooting.
        # EventMachine will cause a Ruby SegFault if all connections are closed in a loop.
        ESM::Websocket.connections { |_server_id, connection| connection.send(:on_close) }

        ESM::Websocket::Request::Overseer.die
        @server.stop
      end
    end
  end
end
