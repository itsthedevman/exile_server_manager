# frozen_string_literal: true

require "nats/client"
require "active_support/log_subscriber"

module ESM
  module Service
    ##
    # Website → bot request/reply client over NATS.
    #
    # Signs every wire envelope with `HMAC-SHA256(body, shared_secret)` so the bot
    # can verify the request originated from a trusted website process. Holds a
    # single shared NATS connection per process; subsequent calls reuse it, and
    # `nats-pure` transparently reconnects on drop.
    #
    # Top-level (not ESM::) on purpose: this is website-local infrastructure, not
    # part of the shared core namespace. Keeping it out of ESM:: also means Zeitwerk
    # never co-owns that namespace, which the Loader chain in
    # config/initializers/esm.rb manages by hand.
    #
    # @example
    #   ESM::Service::API.call(:ping, hello: "world")
    #   # => { echo: { hello: "world" }, server_time: ... }
    #
    class API
      # Transport failures where the request never reached the bot, so retrying can't double-run a command - always safe
      # to retry. Covers a broker reconnect and the gap while a restarting bot re-subscribes.
      UNDELIVERED_ERRORS = [
        NATS::IO::NoServersError,
        NATS::IO::NoRespondersError,
        NATS::IO::ConnectionClosedError,
        NATS::IO::ConnectionDrainingError,
        Errno::ECONNREFUSED
      ].freeze

      # Every transport failure that ends a call as Unreachable. A timeout is ambiguous - the bot may have run the request
      # before its reply was lost - so it retries only for reads the caller marks idempotent, never for a command dispatch
      # that could then fire twice.
      RETRYABLE_ERRORS = (UNDELIVERED_ERRORS + [NATS::IO::Timeout]).freeze

      # A restart clears in well under a second, so a few short, growing backoffs ride it out without hanging the request
      # on a bot that is genuinely down. A timeout attempt already costs the full request timeout, so the worst-case wait
      # is bounded by these attempts times that timeout.
      MAX_ATTEMPTS = 3
      RETRY_BACKOFF = 0.1

      # Retrying is this class's job, not the driver's. Left at its default of 10, nats-pure runs its own loop inside a
      # single #connect - ten attempts, each a connect timeout plus a two second sleep - so one call against a down bot
      # blocks for the better part of a minute before this class sees its first error, and the bound above becomes
      # fiction. Zero makes nats-pure try once and hand the failure up, leaving one retry policy instead of two nested
      # ones.
      #
      # Losing an established connection is unaffected: nats-pure parks a client it won't reconnect at DISCONNECTED
      # rather than CLOSED, and dials again on the next request.
      MAX_DRIVER_RECONNECTS = 0

      # The website drives this connection purely as a request/reply client. Its only subscription is nats-pure's internal
      # response mux, whose callback merely signals the waiting request thread - it touches no app code or Rails-managed
      # resource. nats-pure's Rails engine otherwise wraps every reply delivery in Rails.application.reloader.wrap; once a
      # dev reload is pending, that wrap contends on the reloader interlock with the very web request blocked on the reply,
      # so the reply never lands and the call times out. Opting back into nats-pure's plain non-Rails default (a no-op)
      # keeps reply delivery off the interlock entirely.
      NO_OP_RELOADER = proc { |&block| block.call }

      # ANSI bold-on and reset, composed from ActiveSupport's mode table rather than hardcoded so the coloring tracks
      # whatever codes its SQL logger uses.
      BOLD = "\e[#{ActiveSupport::LogSubscriber::MODES.fetch(:bold)}m".freeze
      RESET = "\e[#{ActiveSupport::LogSubscriber::MODES.fetch(:clear)}m".freeze

      class << self
        ##
        # Sends a signed request through the shared per-process client.
        #
        # @param action [Symbol, String] RPC action name (becomes the subject suffix)
        # @param idempotent [Boolean] when true, a timeout is also retried - set only for reads, never a command dispatch
        # @param payload [Hash] keyword arguments forwarded as the wire payload
        #
        # @return [Object] whatever the bot's handler returned
        #
        # @raise [Unreachable] when the transport can't reach the bot
        # @raise [RemoteError] when the bot responds with `ok: false`
        #
        def call(action, idempotent: false, **payload)
          instance.call(action, idempotent:, **payload)
        end

        ##
        # Returns the per-process shared client, building it under a mutex on
        # first access so two Puma threads on a cold boot don't open competing
        # NATS connections.
        #
        # @return [ESM::Service::API]
        #
        def instance
          return @instance if @instance

          mutex.synchronize { @instance ||= new }
        end

        ##
        # Closes the shared connection and clears the cached instance so the
        # next call rebuilds against current Settings. Primarily for tests that
        # swap `Settings.nats.*` between examples.
        #
        def reset!
          mutex.synchronize do
            @instance&.close
            @instance = nil
          end
        end

        private

        def mutex
          @mutex ||= Mutex.new
        end
      end

      ##
      # @param url [String, nil] NATS broker URL; defaults to `Settings.nats.url`
      # @param secret [String, nil] HMAC shared secret; defaults to `Settings.nats.shared_secret`
      # @param subject_prefix [String, nil] subject namespace; defaults to `Settings.nats.subject_prefix`
      # @param timeout [Numeric, nil] per-request timeout in seconds; defaults to `Settings.nats.request_timeout`
      #
      def initialize(url: nil, secret: nil, subject_prefix: nil, timeout: nil)
        @url = url || Settings.nats.url
        @subject_prefix = subject_prefix || Settings.nats.subject_prefix
        @timeout = timeout || Settings.nats.request_timeout
        @secret = secret || Settings.nats.shared_secret

        @endpoint = nil
        @mutex = Mutex.new
      end

      ##
      # Sends a signed request and returns the handler's result. A transport failure is retried on a short backoff (see
      # {UNDELIVERED_ERRORS}); a timeout is retried too only when the caller marks the call idempotent.
      #
      # @param action [Symbol, String] RPC action name
      # @param idempotent [Boolean] when true, a timeout is also retried - set only for reads, never a command dispatch
      # @param payload [Hash] forwarded as the wire payload
      #
      # @return [Object] whatever the bot's handler returned
      #
      # @raise [Unreachable] on transport failure: no broker, request timeout,
      #   connection refused, or no subscriber for the subject
      # @raise [RemoteError] when the bot responds with `ok: false`, or the reply
      #   envelope can't be parsed. `error_type` carries the wire-level code.
      #
      def call(action, idempotent: false, **payload)
        attempts = 0

        begin
          attempts += 1
          envelope = build_envelope(action: action, payload: payload)
          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          response = endpoint.request("#{@subject_prefix}#{action}", envelope.to_json, timeout: @timeout)

          # The reply landed, so the bot answered this round trip - log it before parsing, so a bot-level ok:false still
          # counts as one call made.
          log_call(action, started_at)

          parsed = response.data.parse_json

          raise RemoteError.new(:invalid_response, "Response envelope could not be parsed") unless parsed.is_a?(Hash)
          raise RemoteError.new(parsed[:error], parsed[:detail]) unless parsed[:ok]

          parsed[:result]
        rescue *RETRYABLE_ERRORS => e
          if should_retry?(e, attempts, idempotent:)
            sleep(RETRY_BACKOFF * attempts)

            Rails.logger.debug(colorize(
              "  ESM::Service::API - Retry attempt #{attempts}",
              ActiveSupport::LogSubscriber::YELLOW
            ))

            retry
          end

          log_call(action, started_at, error: e.message)
          raise Unreachable, e.message
        end
      end

      ##
      # Closes the underlying NATS connection. A subsequent {#call} lazily
      # reconnects.
      #
      def close
        @mutex.synchronize do
          @endpoint&.close
          @endpoint = nil
        end
      end

      private

      # Whether a rescued transport failure warrants another attempt: the undelivered ones always (they never reached the
      # bot), a timeout only for an idempotent read, and neither once the attempt budget is spent.
      def should_retry?(error, attempts, idempotent:)
        return false if attempts >= MAX_ATTEMPTS
        return true if UNDELIVERED_ERRORS.any? { |type| error.is_a?(type) }

        idempotent && error.is_a?(NATS::IO::Timeout)
      end

      # One colored line per bot round trip, shaped like ActiveRecord's SQL logging so the count and timing of
      # website → bot calls reads at a glance alongside the query log. A completed call logs magenta; a transport failure
      # logs red with the reason.
      def log_call(action, started_at, error: nil)
        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)

        detail = error ? "#{action} (#{error})" : action
        color = error ? ActiveSupport::LogSubscriber::RED : ActiveSupport::LogSubscriber::MAGENTA

        Rails.logger.debug(colorize("  ESM::Service::API (#{duration}ms)  #{detail}", color))
      end

      # Wraps a log line in bold color when colorized logging is on and leaves it plain otherwise, following the same
      # switch ActiveRecord's SQL log obeys so these lines color exactly when those do.
      def colorize(message, color)
        return message unless ActiveSupport::LogSubscriber.colorize_logging

        "#{BOLD}#{color}#{message}#{RESET}"
      end

      def endpoint
        return @endpoint if @endpoint

        # NATS.connect builds the client with no options and only sets the reloader from initialize, so the reloader must
        # be passed to Client.new directly - handed to NATS.connect it is silently dropped.
        @mutex.synchronize do
          @endpoint ||= NATS::Client.new(@url, reloader: NO_OP_RELOADER)
            .tap { |client| client.connect(@url, max_reconnect_attempts: MAX_DRIVER_RECONNECTS) }
        end
      end

      def build_envelope(action:, payload:)
        body = {
          action: action,
          payload: payload,
          issued_at: Time.now.to_i,
          nonce: SecureRandom.uuid
        }.to_json

        {
          body: body,
          signature: OpenSSL::HMAC.hexdigest("SHA256", @secret, body)
        }
      end
    end
  end
end
