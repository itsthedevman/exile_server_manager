# frozen_string_literal: true

require_relative "websocket_client/responses"

#
# In-process replacement for the V1 Arma "DLL" client. Pre-rework, this used Faye::WebSocket +
# EventMachine to connect to the bot's localhost WebSocket server, which was slow (~500ms
# handshake per spec), order-dependent (shared EM reactor), and unnecessary for tests.
#
# The new implementation registers a fake `ESM::Websocket` subclass directly in
# `ESM::Websocket.connections[server_id]`. When the bot calls `connection.deliver!(request)`, this
# fake synchronously routes the request to the matching `response_<command>` method (defined in
# `WebsocketClient::Responses`) and dispatches the synthetic reply through the same
# `ServerRequest#process` pipeline production uses.
#
# The public spec API (`flags`, `connected?`, `disconnect!`, `send_xm8_notification`) is preserved.
#
class WebsocketClient
  include WebsocketClient::Responses

  attr_reader :server_id, :flags, :connection

  #
  # Build a fake client that's already connected and registered.
  #
  # @param server [ESM::Server]
  #
  def initialize(server)
    @server = server
    @server_id = server.server_id
    @flags = OpenStruct.new
    @connected = false

    # Authenticate against the server_key the same way production does. If the
    # key doesn't match a real ESM::Server, we leave @connected false so specs
    # that test rejection of bad keys can verify that path.
    ar_server = ESM::Server.where(server_key: server.server_key).first
    return if ar_server.nil?

    @connection = WebsocketClient::FakeConnection.new(server: ar_server, client: self)
    @connection.ready = true

    # Synchronously hand-shake. The bot needs the `server_initialization`
    # message to populate server data and reply with `post_initialization`.
    deliver_to_bot(**initialization_payload)
    @connected = true
  end

  #
  # @return [Boolean] whether the handshake completed
  #
  def connected?
    @connected
  end

  #
  # Tear down the registration. Idempotent.
  #
  def disconnect!
    return if @connection.nil?

    ESM::Websocket.remove_connection(@connection)
    @connection = nil
    @connected = false
  end

  #
  # Push an xm8 notification message TO the bot.
  #
  # @param type [String] notification type (e.g. "base-raid")
  # @param recipients [Array<String>] steam UIDs to notify
  # @param message [String, Hash] notification body
  #
  def send_xm8_notification(type:, recipients:, message:, **extras)
    payload = {type: type, recipients: {r: recipients}.to_json}.merge(extras)
    payload[:message] = message.is_a?(Hash) ? message.to_json : message

    deliver_to_bot(command: "xm8_notification", parameters: [payload])
  end

  #
  # Hook called by {FakeConnection#deliver!} when the bot sends a request to
  # "Arma". Looks up the response config and dispatches to the matching
  # `response_<command>` handler defined in {Responses}.
  #
  # @param json [String] the bot's outgoing message JSON
  #
  def receive_from_bot(json)
    @data = json.to_ostruct
    config = WebsocketClient::Responses::CONFIG[@data.command.to_sym]

    if config.nil?
      ESM.logger.error("WebsocketClient#receive_from_bot") { "Missing config for command `#{@data.command}`" }
      return
    end

    send_ignore_message if config[:send_ignore_message]

    public_send(:"response_#{@data.command}")
  end

  #
  # Used by Responses to send the canned reply back to the bot. The
  # `:commandID` key is auto-attached so the bot's ServerRequest matches
  # the reply to the original request.
  #
  def send_response(**args)
    args[:commandID] = @data.commandID if @data

    deliver_to_bot(**args)
  end

  private

  def deliver_to_bot(**payload)
    json = DiscordReturn.new(**payload).to_json
    @connection.simulate_arma_message(json)
  end

  def send_ignore_message
    deliver_to_bot(commandID: @data&.commandID, ignore: true)
  end

  def initialization_payload
    {
      command: "server_initialization",
      parameters: [{
        server_name: Faker::Commerce.product_name,
        price_per_object: 150,
        territory_lifetime: 7,
        server_restart: [3, 30],
        server_start_time: DateTime.now.utc.strftime("%Y-%m-%dT%H:%M:%S"),
        server_version: "2.0.0",
        territory_level_1: {level: 1, purchase_price: 5000, radius: 15, object_count: 30},
        territory_level_2: {level: 2, purchase_price: 10_000, radius: 30, object_count: 60},
        territory_level_3: {level: 3, purchase_price: 15_000, radius: 45, object_count: 90},
        territory_level_4: {level: 4, purchase_price: 20_000, radius: 60, object_count: 120},
        territory_level_5: {level: 5, purchase_price: 25_000, radius: 75, object_count: 150},
        territory_level_6: {level: 6, purchase_price: 30_000, radius: 90, object_count: 180},
        territory_level_7: {level: 7, purchase_price: 35_000, radius: 105, object_count: 210},
        territory_level_8: {level: 8, purchase_price: 40_000, radius: 120, object_count: 240},
        territory_level_9: {level: 9, purchase_price: 45_000, radius: 135, object_count: 270},
        territory_level_10: {level: 10, purchase_price: 50_000, radius: 150, object_count: 300}
      }]
    }
  end
end

require_relative "websocket_client/fake_connection"
