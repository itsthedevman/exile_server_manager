# frozen_string_literal: true

describe ESM::Command::Server::Promote, category: "command" do
  let!(:command) { ESM::Command::Server::Promote.new }
  let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

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

    # If you need a second set
    let(:second_user) { ESM::Test.second_user }

    # If you need to connect to a server
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "!promote" do
      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id,
        target: second_user.mention
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(
        /hey #{user.mention}, `#{second_user.steam_uid}` has been promoted to moderator in territory `#{territory_id}` on `#{server.server_id}`/i
      )
    end

    it "!promote (Unregistered discord target)" do
      second_user.update(steam_uid: "")

      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id,
        target: second_user.mention
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data
        expect(embed.description).to match(/has not registered with me yet/i)
      end
    end

    it "!promote (Unlinked steam uid)" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id,
        target: steam_uid
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(
        /hey #{user.mention}, `#{steam_uid}` has been promoted to moderator in territory `#{territory_id}` on `#{server.server_id}`/i
      )
    end
  end
end
