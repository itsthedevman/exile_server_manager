# frozen_string_literal: true

describe ESM::Command::Server::Gamble, category: "command" do
  let!(:command) { ESM::Command::Server::Gamble.new }

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
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should execute (Number)" do
      request = nil

      command_statement = command.statement(server_id: server.server_id, amount: "300")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be(nil)
      expect(embed.title).not_to be_blank
      expect(embed.description).not_to be_blank
    end

    it "should execute (half)" do
      request = nil
      command_statement = command.statement(server_id: server.server_id, amount: "half")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be(nil)
      expect(embed.title).not_to be_blank
      expect(embed.description).not_to be_blank
    end

    it "should execute (all)" do
      request = nil
      command_statement = command.statement(server_id: server.server_id, amount: "all")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be(nil)
      expect(embed.title).not_to be_blank
      expect(embed.description).not_to be_blank
    end

    it "should execute with not enough poptabs" do
      request = nil
      wsc.flags.NOT_ENOUGH_MONEY = true

      command_statement = command.statement(server_id: server.server_id, amount: "100000000")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/not enough poptabs/i)
    end

    it "should error when gambling 0" do
      command_statement = command.statement(server_id: server.server_id, amount: "0")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /you simply cannot gamble nothing/)
    end

    it "should not allow negative numbers" do
      command_statement = command.statement(server_id: server.server_id, amount: "-1")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)
      expect { command.execute(event) }.to raise_error(ESM::Exception::FailedArgumentParse)
    end

    it "should return the stats" do
      command_statement = command.statement(server_id: server.server_id, amount: "stats")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be(nil)
      expect(embed.fields.size).to eql(14)
    end
  end
end
