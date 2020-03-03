# frozen_string_literal: true

describe ESM::Websocket::ServerRequest do
  # This test needs esm_community/esm_server in order to function
  let!(:community) { create(:esm_community) }
  let!(:server) { create(:esm_malden, community_id: community.id) }
  let!(:user) { create(:user) }

  let!(:client) { WebsocketClient.new(server) }
  let!(:event) { CommandEvent.create(ESM::Command::Test::Base::COMMAND_FULL, user: user) }
  let!(:channel) { ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL) }

  # Wait before pulling this value
  let(:connection) { ESM::Websocket.connections[server.server_id] }

  let(:command) do
    command = ESM::Command::Test::Base.new

    # Execute the command to set up all of the required variables
    expect { command.execute(event) }.not_to raise_error
    command
  end

  let(:request) do
    connection.send(
      :add_request,
      command: command,
      user: user,
      channel: channel,
      parameters: [],
      timeout: 15
    )
  end

  before :each do
    wait_for { client.connected? }.to be(true)

    # Wait for the client to connect before executing the command
    command
  end

  after :each do
    client.disconnect!
  end

  describe "#process" do
    it "should do nothing (server command request)" do
      message = OpenStruct.new(command: "TESTING")
      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
    end

    it "should remove the request" do
      message = OpenStruct.new(commandID: request.id, parameters: [])

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
      expect(connection.requests.size).to eql(0)
    end

    it "should send the error (server error)" do
      message = OpenStruct.new(commandID: request.id, error: "This is an error")

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.to raise_error(ESM::Exception::CheckFailure)
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/this is an error/i)
    end

    it "should send the error (server command error)" do
      message = { commandID: request.id, error: "", parameters: [{ error: "This is an error" }] }.to_ostruct

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.to raise_error(ESM::Exception::CheckFailure)
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/this is an error/i)
    end

    it "should send the error (command error)" do
      message = { commandID: request.id, parameters: [] }.to_ostruct

      # Set a flag so our command raises an error
      command.defines.FLAG_RAISE_ERROR = true

      expect { ESM::Websocket::ServerRequest.new(connection: connection, message: message).process }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/this failed a check/i)
    end
  end
end
