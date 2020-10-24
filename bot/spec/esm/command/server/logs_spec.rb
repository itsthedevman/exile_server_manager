# frozen_string_literal: true

describe ESM::Command::Server::Logs, category: "command" do
  let!(:command) { ESM::Command::Server::Logs.new }

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

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)

      # Allow user to use this command
      community.command_configurations.where(command_name: "logs").update(whitelist_enabled: false)
    end

    after :each do
      wsc.disconnect!
    end

    it "!logs <server_id> <target>" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.steam_uid)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i)

      expect(ESM::Log.all.size).to eql(1)
      expect(ESM::Log.all.first.search_text).to eql(second_user.steam_uid)
      expect(ESM::LogEntry.all.size).not_to eql(0)

      ESM::LogEntry.all.each do |entry|
        expect(entry.entries).not_to be_empty
      end
    end

    it "!logs <server_id> <query>" do
      command_statement = command.statement(server_id: server.server_id, target: "testing")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i)

      expect(ESM::Log.all.size).to eql(1)
      expect(ESM::Log.all.first.search_text).to eql("testing")
      expect(ESM::LogEntry.all.size).not_to eql(0)

      ESM::LogEntry.all.each do |entry|
        expect(entry.entries).not_to be_empty
      end
    end

    it "should handle no logs" do
      wsc.flags.NO_LOGS = true

      command_statement = command.statement(server_id: server.server_id, target: "testing")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/hey .+, i was unable to find any logs that match your query./i)
    end
  end
end
