# frozen_string_literal: true

describe ESM::Websocket::ServerRequest do
  include_context "command" do
    let!(:command_class) { ESM::Command::Test::BaseV1 }

    # This test needs esm_community/esm_server in order to function
    let!(:community) { create(:esm_community) }
    let!(:server) { create(:esm_malden, community_id: community.id) }
  end

  let!(:client) { WebsocketClient.new(server) }
  let!(:channel) { community.discord_server.channels.first }

  # Wait before pulling this value
  let(:connection) { ESM::Websocket.connections[server.server_id] }

  let(:request) do
    request = ESM::Websocket::Request.new(
      command: previous_command,
      user: user,
      channel: channel,
      parameters: [],
      timeout: 15
    )

    connection.requests << request

    request
  end

  before do
    wait_for { client.connected? }.to be(true)

    # Wait for the client to connect before executing the command
    execute!(
      channel: channel,
      arguments: {
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_name",
        _default: "default"
      }
    )
  end

  after do
    client.disconnect!
  end

  describe "#process" do
    it "does nothing (server command request)" do
      message = OpenStruct.new(command: "TESTING")
      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
    end

    it "removes the request" do
      message = OpenStruct.new(commandID: request.id, parameters: [])

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
      expect(connection.requests.size).to eq(0)
    end

    it "sends the error (server error)" do
      message = OpenStruct.new(commandID: request.id, error: "This is an error")

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
      ESM.discord_bot.test_outbox.await_size(1)

      embed = ESM.discord_bot.test_outbox.first.content
      expect(embed.description).to match(/this is an error/i)
    end

    it "sends the error (server command error)" do
      message = {commandID: request.id, error: "", parameters: [{error: "This is an error"}]}.to_ostruct

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
      ESM.discord_bot.test_outbox.await_size(1)

      embed = ESM.discord_bot.test_outbox.first.content
      expect(embed.description).to match(/this is an error/i)
    end

    it "sends the error (command error)" do
      # Set a flag so our command raises an error
      previous_command.instance_variable_set(:@raise_error, true)

      message = {commandID: request.id, parameters: []}.to_ostruct

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
      ESM.discord_bot.test_outbox.await_size(1)

      embed = ESM.discord_bot.test_outbox.first.content
      expect(embed.description).to match(/this failed a check/i)
    end
  end
end
