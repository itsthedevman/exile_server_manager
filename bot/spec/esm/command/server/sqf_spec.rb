# frozen_string_literal: true

describe ESM::Command::Server::Sqf, category: "command" do
  let!(:command) { ESM::Command::Server::Sqf.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 3 argument" do
    expect(command.arguments.size).to eql(3)
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
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      # Allow user to use this command
      community.command_configurations.where(command_name: "sqf").update(whitelist_enabled: false)

      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    # Flags
    # WITH_RETURN
    # ERROR
    it "should execute (Server/with reply)" do
      wsc.flags.WITH_RETURN = true

      request = nil
      command_statement = command.statement(server_id: server.server_id, code_to_execute: "_test = true;\n_test")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).to have_attributes(description: a_string_matching(/executed your code successfully and the code returned the following: ```true```/i))
    end

    it "should execute (Server/no reply)" do
      request = nil
      command_statement = command.statement(server_id: server.server_id, code_to_execute: "if (false) then { \"true\" };")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).to have_attributes(description: a_string_matching(/executed your code successfully and the code returned nothing/i))
    end

    it "should execute (Target/no reply)" do
      request = nil
      command_statement = command.statement(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).to have_attributes(description: a_string_matching(/executed your code successfully on `#{user.steam_uid}`/i))
    end

    it "should raise not online target" do
      wsc.flags.ERROR = true

      request = nil
      command_statement = command.statement(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).to have_attributes(description: a_string_matching(/has informed me that `#{user.steam_uid}` is not online or has not joined the server/i))
    end

    it "should raise not registered target" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      second_user.update(steam_uid: "")

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data).to have_attributes(description: a_string_matching(/has not registered with me yet/i))
      end
    end

    it "should support a non-registered steam uid" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(server_id: server.server_id, target: steam_uid, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).to have_attributes(description: a_string_matching(/executed your code successfully on `#{steam_uid}`/i))
    end
  end
end
