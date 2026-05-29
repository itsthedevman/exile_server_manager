# frozen_string_literal: true

require "nats/client"

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
#   IpcClient.call(:ping, hello: "world")
#   # => { echo: { hello: "world" }, server_time: ... }
#
class IpcClient
  class << self
    ##
    # Sends a signed request through the shared per-process client.
    #
    # @param action [Symbol, String] RPC action name (becomes the subject suffix)
    # @param payload [Hash] keyword arguments forwarded as the wire payload
    #
    # @return [Object] whatever the bot's handler returned
    #
    # @raise [Unreachable] when the transport can't reach the bot
    # @raise [RemoteError] when the bot responds with `ok: false`
    #
    def call(action, **payload)
      instance.call(action, **payload)
    end

    ##
    # Returns the per-process shared client, building it under a mutex on
    # first access so two Puma threads on a cold boot don't open competing
    # NATS connections.
    #
    # @return [IpcClient]
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
  # Sends a signed request and returns the handler's result.
  #
  # @param action [Symbol, String] RPC action name
  # @param payload [Hash] forwarded as the wire payload
  #
  # @return [Object] whatever the bot's handler returned
  #
  # @raise [Unreachable] on transport failure: no broker, request timeout,
  #   connection refused, or no subscriber for the subject
  # @raise [RemoteError] when the bot responds with `ok: false`, or the reply
  #   envelope can't be parsed. `error_type` carries the wire-level code.
  #
  def call(action, **payload)
    envelope = build_envelope(action: action, payload: payload)

    response = endpoint.request("#{@subject_prefix}#{action}", envelope.to_json, timeout: @timeout)
    parsed = response.data.parse_json

    raise RemoteError.new(:invalid_response, "Response envelope could not be parsed") unless parsed.is_a?(Hash)
    raise RemoteError.new(parsed[:error], parsed[:detail]) unless parsed[:ok]

    parsed[:result]
  rescue NATS::IO::Timeout,
    NATS::IO::NoServersError,
    NATS::IO::NoRespondersError,
    NATS::IO::ConnectionClosedError,
    NATS::IO::ConnectionDrainingError,
    Errno::ECONNREFUSED => e
    raise Unreachable, e.message
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

  def endpoint
    return @endpoint if @endpoint

    @mutex.synchronize { @endpoint ||= NATS.connect(@url) }
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
