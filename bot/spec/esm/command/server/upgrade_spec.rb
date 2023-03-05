# frozen_string_literal: true

describe ESM::Command::Server::Upgrade, category: "command" do
  let!(:command) { ESM::Command::Server::Upgrade.new }
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

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "!upgrade" do
      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eq("Hey #{user.mention}, you successfully upgraded territory `#{territory_id}` for **#{response.cost.to_poptab}**.\nYour territory has reached level **#{response.level}** and now has a radius of **#{response.range}** meters.\nAfter this transaction, you have **#{response.locker.to_poptab}** left in your locker.")
    end
  end
end
