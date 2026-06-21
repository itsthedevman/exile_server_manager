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
        # Reject envelopes whose `issued_at` is more than this many seconds
        # off our wall-clock in either direction. Bounds the replay window
        # for a captured signed envelope.
        ENVELOPE_MAX_AGE_SECONDS = 5 * 60

        class << self
          ##
          # Boots the singleton, registers handlers, opens subscriptions.
          #
          # @return [Server] the running instance
          #
          def start
            stop # Ensure the any running instances are cleaned up

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
            # Load handlers from api/handlers
            Handlers.constants(false).sort.each do |constant_name|
              # server.register(:ping, Handlers::Ping)
              server.register(constant_name.to_s.underscore, "#{Handlers}::#{constant_name}".constantize)
            end
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
            @nats.subscribe("#{@subject_prefix}#{action}") do |message|
              ESM::Database.with_connection { dispatch(action, handler, message) }
            end
          end

          info!(event: "website_api:start", subjects: @handlers.keys)

          self
        rescue => e
          error!(event: "website_api:start_failed", error: e)
        end

        ##
        # Drains pending messages and closes the connection. Tolerant of a
        # broker that's already gone (drain raises ConnectionClosedError in
        # that case) so process shutdown can continue with the rest of the
        # tear-down chain.
        #
        def stop
          return unless @nats

          begin
            @nats.drain
          rescue => e
            warn!(event: "website_api:stop_error", error: e)
          end

          @nats = nil

          info!(event: "website_api:stop")
        end

        private

        def dispatch(action, handler, message)
          envelope = message.data.parse_json
          return reject(message, action, :signature_invalid, "envelope rejected") unless verify_signature(envelope)

          body = envelope[:body].parse_json
          return reject(message, action, :invalid_envelope, "envelope rejected") unless body.is_a?(Hash)
          return reject(message, action, :invalid_envelope, "envelope rejected") if stale_envelope?(body)

          payload = body[:payload] || {}
          payload = {} unless payload.is_a?(Hash)

          info!(event: action, **payload)

          result = handler.call(**payload)

          # A handler may offload a slow operation (e.g. an Arma round-trip) to a
          # Concurrent::Promise and return it. When it does, free this dispatch
          # thread now and reply once the promise resolves, so one blocking handler
          # can't stall the other RPCs sharing the NATS subscription.
          if result.is_a?(Concurrent::Promise)
            respond_when_resolved(message, action, result)
          elsif result.is_a?(ESM::ServerCommand)
            message.respond({ok: true}.to_json)
          else
            message.respond({ok: true, result:}.to_json)
          end
        rescue => e
          # Full error stays in the bot's logs; the wire response carries a
          # generic detail so we don't leak AR/discordrb internals back to the
          # caller. (Per dispatch comment: no oracle for the caller.)
          error!(event: "website_api:error", action:, error: e)
          respond_error(message, :unknown, "internal handler error")
        end

        # Replies once the handler's offloaded promise resolves, mirroring the
        # synchronous path's success/error shapes. The full error stays in the
        # bot's logs; the wire response stays generic.
        def respond_when_resolved(message, action, promise)
          promise
            .then { |value| message.respond({ok: true, result: value}.to_json) }
            .rescue do |reason|
              error!(event: "website_api:error", action:, error: reason)
              respond_error(message, :unknown, "internal handler error")
            end
        end

        # Treats a missing or non-integer issued_at as "too old to trust"
        # so a malformed/replayed envelope can't sneak past timestamp checks.
        def stale_envelope?(body)
          issued_at = body[:issued_at]
          return true unless issued_at.is_a?(Integer)

          (Time.now.to_i - issued_at).abs > ENVELOPE_MAX_AGE_SECONDS
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
