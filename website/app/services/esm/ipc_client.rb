# frozen_string_literal: true

require "nats/client"

module ESM
  # Website → bot request/reply client over NATS.
  #
  # Signs every wire envelope with `HMAC-SHA256(body, shared_secret)` so
  # the bot can verify the request originated from a trusted website
  # process. Holds a single shared NATS connection per process;
  # subsequent calls reuse it, and `nats-pure` transparently reconnects
  # on drop.
  #
  # @example
  #   result = ESM::IpcClient.call(:ping, hello: "world")
  #   result.value # => { echo: { hello: "world" }, server_time: ... }
  class IpcClient
    # Raised when the transport itself can't reach the bot (no broker,
    # request timeout, connection refused). The caller typically maps
    # this to a user-facing "service unavailable" state.
    class Unreachable < StandardError; end

    # Raised when the bot responded with `ok: false`. Carries the
    # structured error type (symbol) the bot chose, plus the detail
    # string.
    class RemoteError < StandardError
      attr_reader :error_type

      def initialize(error_type, detail)
        @error_type = error_type.to_s.to_sym
        super(detail.to_s)
      end
    end

    Result = Data.define(:ok, :value, :error_type, :error_message) do
      def ok? = ok
    end

    class << self
      # Sends a signed request and returns a Result, or raises on failure.
      def call(action, **payload)
        instance.call(action, **payload)
      end

      # Shared per-process client. Lazily instantiated.
      def instance
        @instance ||= new
      end

      # Closes the shared connection and forces a fresh one on next call.
      # Primarily for tests.
      def reset!
        @instance&.close
        @instance = nil
      end
    end

    def initialize(url: nil, secret: nil, subject_prefix: nil, timeout: nil)
      @url = url || Settings.nats.url
      @subject_prefix = subject_prefix || Settings.nats.subject_prefix
      @timeout = timeout || Settings.nats.request_timeout
      @secret = secret || ENV.fetch(Settings.nats.shared_secret_env)
      @nats = nil
      @mutex = Mutex.new
    end

    # Sends a signed request and returns a `Result` on success. Raises
    # `Unreachable` on transport failure or `RemoteError` on `ok: false`.
    def call(action, **payload)
      subject = "#{@subject_prefix}#{action}"
      envelope = build_envelope(action: action, payload: payload)

      response = nats.request(subject, envelope.to_json, timeout: @timeout)
      parsed = response.data.parse_json
      raise RemoteError.new(:invalid_response, "Response envelope could not be parsed") unless parsed.is_a?(Hash)

      if parsed[:ok]
        Result.new(ok: true, value: parsed[:result], error_type: nil, error_message: nil)
      else
        raise RemoteError.new(parsed[:error], parsed[:detail])
      end
    rescue NATS::IO::Timeout, NATS::IO::NoServersError, Errno::ECONNREFUSED => e
      raise Unreachable, e.message
    end

    def close
      @mutex.synchronize do
        @nats&.close
        @nats = nil
      end
    end

    private

    def nats
      return @nats if @nats

      @mutex.synchronize { @nats ||= NATS.connect(@url) }
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
