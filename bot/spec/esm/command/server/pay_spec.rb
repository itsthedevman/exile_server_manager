# frozen_string_literal: true

describe ESM::Command::Server::Pay, category: "command" do
  let!(:command) { ESM::Command::Server::Pay.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
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

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should return" do
      request = nil
      command_statement = command.statement(server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5])
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/has successfully received the payment/i)
    end
  end
end
