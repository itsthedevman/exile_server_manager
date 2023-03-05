# frozen_string_literal: true

describe ESM::Command::Server::Restore, category: "command" do
  let!(:command) { ESM::Command::Server::Restore.new }
  let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 2 argument" do
    expect(command.arguments.size).to eq(2)
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

    let(:second_community) { ESM::Test.second_community }
    let(:second_server) { ESM::Test.second_server }

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)

      grant_command_access!(community, "restore")
    end

    after :each do
      wsc.disconnect!
    end

    it "!restore (success)" do
      wsc.flags.SUCCESS = true

      command_statement = command.statement(server_id: server.server_id, territory_id: territory_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eq("Hey #{user.mention}, `#{territory_id}` has been restored")
    end

    it "!restore (failure)" do
      wsc.flags.SUCCESS = false

      command_statement = command.statement(server_id: server.server_id, territory_id: territory_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eq("I'm sorry #{user.mention}, `#{territory_id}` no longer exists on `#{server.server_id}`.")
    end
  end
end
