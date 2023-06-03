# frozen_string_literal: true

describe ESM::Command::Server::Stuck, category: "command" do
  let!(:command) { ESM::Command::Server::Stuck.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
    expect(command.arguments.size).to eq(1)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "!stuck <server_id> (Success)" do
      wsc.flags.SUCCESS = true
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # If the command is for a server
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Reset so we can track the response
      ESM::Test.messages.clear

      # Respond to the request
      request.respond(true)

      wait_for { connection.requests }.to be_blank

      wait_for { ESM::Test.messages.size }.to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/you've been reset successfully. please join the server to spawn back in/i)
    end

    it "!stuck <server_id> (Failure)" do
      wsc.flags.SUCCESS = false
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # If the command is for a server
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Reset so we can track the response
      ESM::Test.messages.clear

      # Respond to the request
      request.respond(true)

      wait_for { connection.requests }.to be_blank

      wait_for { ESM::Test.messages.size }.to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/i was not successful at resetting your player on `.+`\. please join the server again, and if you are still stuck, close arma 3 and attempt this command again\./i)
    end
  end
end
