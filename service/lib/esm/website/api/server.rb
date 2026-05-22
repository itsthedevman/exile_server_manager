# frozen_string_literal: true

require "nats/client"

module ESM
  module Website
    class API
      ##
      # NATS request/reply listener. Subscribes to `esm.bot.rpc.<action>` subjects and
      # dispatches each incoming message to a registered handler. Every envelope is
      # HMAC-SHA256 signed by the website and verified here before the handler runs.
      #
      # Adding a new RPC: one line in {.register_handlers} pointing at a handler class
      # under {Handlers}.
      #
      class Server
        class << self
          ##
          # Boots the singleton, registers handlers, opens subscriptions.
          #
          # @return [Server] the running instance
          #
          def start
            @instance = new

            register_handlers(@instance)

            @instance.start
          end

          ##
          # Drains and closes the NATS connection.
          #
          def stop
            @instance&.stop
            @instance = nil
          end

          private

          def register_handlers(server)
            server.register(:ping, Handlers::Ping)
          end
        end

        def initialize
          @url = Settings.nats.url
          @subject_prefix = Settings.nats.subject_prefix
          @secret = Settings.nats.shared_secret
          @handlers = {}
          @nats = nil
        end

        ##
        # Registers a handler for an action. The handler must respond to
        # `call(**payload)` and return a hash.
        #
        # @param action [Symbol, String] action name (becomes subject suffix)
        # @param handler [#call] handler class or callable
        #
        # @return [Server] self, for chaining
        #
        def register(action, handler)
          @handlers[action.to_sym] = handler
          self
        end

        ##
        # Connects to NATS and subscribes one subject per registered handler.
        #
        # @return [Server] self
        #
        def start
          return self if @nats

          @nats = NATS.connect(@url)

          @handlers.each do |action, handler|
            subject = "#{@subject_prefix}#{action}"
            @nats.subscribe(subject) { |message| dispatch(action, handler, message) }
          end

          info!(event: "website_api:start", subjects: @handlers.keys)

          self
        end

        ##
        # Drains pending messages and closes the connection.
        #
        def stop
          return unless @nats

          @nats.drain
          @nats = nil

          info!(event: "website_api:stop")
        end

        private

        def dispatch(action, handler, message)
          envelope = message.data.parse_json
          return reject(message, action, :signature_invalid, "HMAC verification failed") unless verify_signature(envelope)

          body = envelope[:body].parse_json
          payload = body[:payload] || {}

          result = handler.call(**payload)
          message.respond({ok: true, result:}.to_json)
        rescue => e
          error!(event: "website_api:error", action:, error: e.class.name, detail: e.message)
          respond_error(message, :unknown, e.message)
        end

        # Returns false on any structural issue rather than raising, so a malformed envelope
        # is rejected with the same code as a tampered one — no oracle for the caller.
        def verify_signature(envelope)
          return false unless envelope.is_a?(Hash)
          return false unless envelope[:body].is_a?(String) && envelope[:signature].is_a?(String)

          expected = OpenSSL::HMAC.hexdigest("SHA256", @secret, envelope[:body])
          OpenSSL.fixed_length_secure_compare(expected, envelope[:signature])
        rescue ArgumentError
          false
        end

        def reject(message, action, error, detail)
          warn!(event: "website_api:reject", action: action, reason: error)
          respond_error(message, error, detail)
        end

        def respond_error(message, error, detail)
          message.respond({ok: false, error:, detail:}.to_json)
        end
      end
    end
  end
end
