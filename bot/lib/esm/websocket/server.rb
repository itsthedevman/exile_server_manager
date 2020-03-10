# frozen_string_literal: true

module ESM
  class Websocket
    class Server
      def initialize
        Faye::WebSocket.load_adapter("puma")
        events = Puma::Events.new($stdout, $stderr)
        binder = Puma::Binder.new(events)
        binder.parse(["tcp://0.0.0.0:#{ENV["WEBSOCKET_PORT"]}"], self)
        @server = Puma::Server.new(self, events)
        @server.binder = binder
        @server.run
      end

      def call(env)
        return if !Faye::WebSocket.websocket?(env)

        # Create a new websocket client
        # Its important that ping is set to 0.5 for tests
        # This was causing issues where the websocket was recieving commands late
        #   with no indication of why, except it would receive the message after 30 seconds.
        #   Randomly, I read that Websocket has a ping built in.
        #   Upon setting the ping to a small number, it fixed it. Ugh
        #   - 2020-03-09
        ws = Faye::WebSocket.new(env, nil, ping: sleep(ESM.env.test? ? 0.5 : 30))

        # Bind it with ESM
        ESM::Websocket.new(ws)

        # Return async Rack response
        ws.rack_response
      end

      def log(*args)
        ESM.logger.info("#{self.class}##{__method__}") { "Websocket server is running on #{args.first}" }
      end

      def stop
        ESM::Websocket::RequestWatcher.stop!
        @server.stop(true)
      end
    end
  end
end
