# frozen_string_literal: true

describe ESM::Command::Server::ServerTerritories, category: "command" do
  let!(:command) { ESM::Command::Server::ServerTerritories.new }

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
      # Grant everyone access to use this command
      configuration = community.command_configurations.where(command_name: "server_territories").first
      configuration.update(whitelist_enabled: false)

      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should return (Default)" do
      request = nil
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to be > 3
    end

    it "should return (Sorted by territory name)" do
      command_statement = command.statement(server_id: server.server_id, order_by: "territory_name")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      request = connection.requests.first

      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to be > 3
      expect(response).to eql(request.response.sort_by(&:territory_name))
    end

    it "should return (Sorted by owner uid)" do
      command_statement = command.statement(server_id: server.server_id, order_by: "owner_uid")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      request = connection.requests.first

      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to be > 3
      expect(response).to eql(request.response.sort_by(&:owner_uid))
    end

    it "should return (No territories)" do
      wsc.flags.RETURN_NO_TERRITORIES = true
      request = nil
      command_statement = command.statement(server_id: server.server_id, order_by: "owner_uid")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      expect(ESM::Test.messages.first.second.description).to match(/it doesn't appear to be any territories on this server/i)
    end
  end
end
