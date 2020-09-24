# frozen_string_literal: true

describe ESM::Command::Server::Reset, category: "command" do
  let!(:command) { ESM::Command::Server::Reset.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 2 argument" do
    expect(command.arguments.size).to eql(2)
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
    let(:second_user) { ESM::Test.second_user }

    # If you need to connect to a server
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      # Allow user to use this command
      community.command_configurations.where(command_name: "reset").update(whitelist_enabled: false)

      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "!reset <server_id> (Success)" do
      wsc.flags.SUCCESS = true
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # If the command is for a server
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message
      expect(ESM::Test.messages.size).to eql(2)

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Reset so we can track the response
      ESM::Test.reset!

      # Respond to the request
      request.respond(true)

      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/i've reset all stuck players\./i)
    end

    it "!reset <server_id> (Failure)" do
      wsc.flags.SUCCESS = false
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # If the command is for a server
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message
      expect(ESM::Test.messages.size).to eql(2)

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Reset so we can track the response
      ESM::Test.reset!

      # Respond to the request
      request.respond(true)

      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/i was unable to find anyone who was stuck\./i)
    end

    it "!reset <server_id> <target> (Success)" do
      wsc.flags.SUCCESS = true
      command_statement = command.statement(server_id: server.server_id, target: second_user.steam_uid)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # If the command is for a server
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message
      expect(ESM::Test.messages.size).to eql(2)

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Reset so we can track the response
      ESM::Test.reset!

      # Respond to the request
      request.respond(true)

      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/has been reset successfully. please instruct them to join the server again to confirm\./i)
    end

    it "!reset <server_id> <target> (Failure)" do
      wsc.flags.SUCCESS = false
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # If the command is for a server
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message
      expect(ESM::Test.messages.size).to eql(2)

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Reset so we can track the response
      ESM::Test.reset!

      # Respond to the request
      request.respond(true)

      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/is not stuck\. please have them join the server again, and if they are still stuck, instruct them to close arma 3 and then attempt this command again\./i)
    end
  end
end
