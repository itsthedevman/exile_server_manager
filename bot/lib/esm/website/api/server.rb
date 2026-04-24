# frozen_string_literal: true

require "nats/client"

module ESM
  module Website
    module API
      #
      # NATS request/reply dispatcher for website → bot communication.
      #
      # Connects outbound to a NATS broker, subscribes to the wildcard
      # subject `<prefix>>`, verifies each envelope's HMAC-SHA256 signature
      # against `ENV["API_AUTH_KEY"]`, dispatches by subject suffix to a
      # registered handler, and responds via `message.respond` with a typed
      # result envelope.
      #
      # Wire envelope (JSON string in `message.data`):
      #   { "body":      "<json-encoded body>",
      #     "signature": "<hex HMAC-SHA256 of body with shared secret>" }
      #
      # The body field is JSON-encoded separately so both sides sign and
      # verify the exact same byte sequence.
      #
      # Response envelope (JSON string via `message.respond`):
      #   { "ok": true,  "result": <handler return value> }
      #   { "ok": false, "error": "<symbol>", "detail": "<optional>" }
      #
      # @example
      #   ESM::Website::API::Server.new
      #     .register("ping", ESM::Website::API::Handlers::Ping.new)
      #     .start
      #
      class Server
        #
        # Default wildcard subject suffix; handlers register under
        # `<SUBJECT_PREFIX><action>`.
        #
        SUBJECT_PREFIX = "esm.bot.rpc."

        #
        # Errors returned in the response envelope `error` field. Reserved
        # values so handlers can't collide with transport-level errors.
        #
        ERRORS = %i[
          invalid_envelope
          signature_invalid
          unknown_action
          handler_error
        ].freeze

        # @return [Hash{String => #call}] registered handlers by action name
        attr_reader :handlers

        # TODOCS
        def initialize(url: nil, secret: nil, subject_prefix: SUBJECT_PREFIX)
          @url = url || ENV.fetch("NATS_URL", "nats://127.0.0.1:4222")
          @secret = secret || ENV.fetch("API_AUTH_KEY")
          @subject_prefix = subject_prefix
          @handlers = {}
          @nats = nil
          @subscription = nil
        end

        #
        # Registers a handler for the given action name.
        #
        # @param action [String, Symbol] subject suffix after the prefix
        # @param handler [#call] anything responding to `call(**payload)`
        #
        # @return [self]
        #
        def register(action, handler)
          @handlers[action.to_s] = handler

          self
        end

        #
        # Connects to NATS and subscribes. Chainable.
        #
        # @return [self]
        #
        def start
          return self if @nats

          info!(event: "website:api:server:start", url: @url, handlers: @handlers.keys)

          @nats = NATS.connect(@url)
          @subscription = @nats.subscribe("#{@subject_prefix}>") { |m| dispatch(m) }

          self
        end

        #
        # Closes the NATS connection.
        #
        def stop
          return unless @nats

          @subscription&.unsubscribe
          @nats.close
          @nats = nil
          @subscription = nil

          info!(event: "website:api:server:stop")
        end

        private

        def dispatch(message)
          action = message.subject.delete_prefix(@subject_prefix)

          envelope = parse_envelope(message.data)
          return respond_error(message, :invalid_envelope, "Envelope malformed or missing fields") unless envelope
          return respond_error(message, :signature_invalid, "HMAC verification failed") unless valid_signature?(envelope)

          handler = @handlers[action]
          return respond_error(message, :unknown_action, "No handler registered for '#{action}'") unless handler

          body = envelope[:body].parse_json
          return respond_error(message, :invalid_envelope, "Body malformed") unless body.is_a?(Hash)

          payload = body[:payload] || {}
          result = handler.call(**payload)

          respond_ok(message, result)
        rescue => e
          error!(event: "website:api:server:dispatch", action: action, error: e)
          respond_error(message, :handler_error, e.message)
        end

        def parse_envelope(data)
          env = data.parse_json
          return nil unless env.is_a?(Hash) && env[:body].is_a?(String) && env[:signature].is_a?(String)

          env
        end

        def valid_signature?(envelope)
          expected = OpenSSL::HMAC.hexdigest("SHA256", @secret, envelope[:body])
          signature = envelope[:signature]
          return false unless signature.bytesize == expected.bytesize

          OpenSSL.fixed_length_secure_compare(expected, signature)
        end

        def respond_ok(message, result)
          message.respond({ok: true, result:}.to_json)
        end

        def respond_error(message, error, detail = nil)
          message.respond({ok: false, error:, detail:}.to_json)
        end
      end
    end
  end
end
