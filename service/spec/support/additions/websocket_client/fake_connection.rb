# frozen_string_literal: true

class WebsocketClient
  #
  # Subclass of `ESM::Websocket` (which serves double duty as the connections registry and the
  # connection-wrapper class) that bypasses the Faye/EM stack. Production
  # `ESM::Websocket#initialize` calls `authorize!`, `bind_events`, and `on_open` against a
  # Faye::WebSocket server connection. We don't have one in tests, and faking it is more complex
  # than just skipping it.
  #
  # Instead, we set the ivars the base class expects (`@server`, `@requests`, `@ready`, `@closed`)
  # directly and implement `deliver!` synchronously.
  #
  class FakeConnection < ESM::Websocket
    attr_reader :client, :last_request

    #
    # @param server [ESM::Server] the AR server this connection represents
    # @param client [WebsocketClient] the test client paired with this
    #   connection. The bot's outgoing requests are forwarded to this client
    #   for response handling.
    #
    def initialize(server:, client:)
      # Intentionally NOT calling super. Base initialize requires a Faye connection object that we
      # don't have.
      @server = server
      @client = client
      @requests = ESM::Websocket::Queue.new
      @ready = false
      @closed = false

      ESM::Websocket.add_connection(self)
    end

    #
    # Override of {ESM::Websocket::Connection#deliver!}. Instead of pushing
    # the request to a real Faye client over the wire, hand the JSON
    # directly to the test client which will synthesise a response.
    #
    # @param request [ESM::Websocket::Request]
    #
    # @return [ESM::Websocket::Request] the same request, for chaining
    #
    def deliver!(request)
      @requests << request
      @last_request = request
      @client.receive_from_bot(request.to_s)
      request
    end

    #
    # Test helper: simulate the "Arma server" sending a message TO the bot.
    # Drives the same `ServerRequest#process` pipeline production uses,
    # synchronously (no `Thread.new`) so specs see effects immediately.
    #
    # @param json [String]
    #
    def simulate_arma_message(json)
      message = json.to_ostruct
      server_request = ESM::Websocket::ServerRequest.new(connection: self, message: message)

      if server_request.invalid?
        server_request.remove_request if server_request.remove_on_ignore?
        return
      end

      @server.reload
      ESM::Database.with_connection { server_request.process }
    rescue => e
      ESM.logger.error("WebsocketClient::FakeConnection#simulate_arma_message") do
        "#{e.message}\n#{e.backtrace[0..5].join("\n")}"
      end
      raise e
    end

    #
    # No-op overrides. The base implementations would touch the Faye connection that we don't have.
    #
    def ping
    end
  end
end
