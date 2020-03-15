# frozen_string_literal: true

require 'faye/websocket'
require 'eventmachine'
require_relative "websocket_client/responses"

# Certain parts of this class are written a particular way as to not disturb the "DLL"'s core functionality
class WebsocketClient
  include WebsocketClient::Responses

  attr_reader :ws
  attr_reader :flags
  attr_reader :server_id
  def initialize(server)
    @thread = Thread.new do
      EventMachine.run do
        @ws = Faye::WebSocket::Client.new(
          "ws://localhost:#{ENV["WEBSOCKET_PORT"]}",
          [],
          headers: { "authorization" => "basic #{Base64.strict_encode64("arma_server:#{server.server_key}")}" }
        )

        @ws.on(:message, &method(:on_message))
        @ws.on(:open, &method(:on_open))
        @ws.on(:close, &method(:on_close))
        @ws.on(:error, &method(:on_error))
        @logging_server_id = server.server_id

        send_initialization_message
      end
    end

    @flags = OpenStruct.new
  end

  def on_message(event)
    @data = event.data.to_ostruct

    ESM.logger.debug("#{self.class}##{__method__}") do
      JSON.pretty_generate(JSON.parse(event.data))
    end

    command_config = WebsocketClient::Responses::CONFIG[@data.command.to_sym]
    raise "Missing command config for: #{@data.command}" if command_config.nil?

    send_ignore_message if command_config[:send_ignore_message]
    delay(command_config[:delay]) if command_config[:delay]

    self.send("response_#{@data.command}".to_sym)
  end

  def on_open(_event); end

  def on_close(_event); end

  def on_error(event)
    ESM.logger.debug("#{self.class}##{__method__}") { "#{@logging_server_id} | ON ERROR\nMessage: #{event.message}" }
  end

  def connected?
    @connected || false
  end

  def on_ping(event); end

  def disconnect!
    @ws.close
    @thread.stop(true)
  end

  def send_response(packet)
    @ws.send(DiscordReturn.new(packet).to_json)
  end

  private

  def send_initialization_message
    send_response(
      command: "server_initialization",
      parameters: [{
        server_name: Faker::Commerce.product_name,
        price_per_object: 150,
        territory_lifetime: 7,
        server_restart: [3, 30],
        server_start_time: DateTime.now.strftime("%Y-%m-%dT%H:%M:%S"),
        server_version: "2.0.0",
        territory_level_1: { level: 1, purchase_price: 5000, radius: 15, object_count: 30 },
        territory_level_2: { level: 2, purchase_price: 10_000, radius: 30, object_count: 60 },
        territory_level_3: { level: 3, purchase_price: 15_000, radius: 45, object_count: 90 },
        territory_level_4: { level: 4, purchase_price: 20_000, radius: 60, object_count: 120 },
        territory_level_5: { level: 5, purchase_price: 25_000, radius: 75, object_count: 150 },
        territory_level_6: { level: 6, purchase_price: 30_000, radius: 90, object_count: 180 },
        territory_level_7: { level: 7, purchase_price: 35_000, radius: 105, object_count: 210 },
        territory_level_8: { level: 8, purchase_price: 40_000, radius: 120, object_count: 240 },
        territory_level_9: { level: 9, purchase_price: 45_000, radius: 135, object_count: 270 },
        territory_level_10: { level: 10, purchase_price: 50_000, radius: 150, object_count: 300 }
      }]
    )
  end

  def send_ignore_message
    send_response(commandID: @data.commandID, ignore: true)
  end

  def delay(range)
    sleep Faker::Number.between(from: range.min, to: range.max)
  end
end
