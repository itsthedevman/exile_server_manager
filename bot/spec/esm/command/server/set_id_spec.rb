# frozen_string_literal: true

describe ESM::Command::Server::SetId, category: "command" do
  let!(:command) { ESM::Command::Server::SetId.new }

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
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should return" do
      request = nil
      statement = command.statement(
        server_id: server.server_id,
        old_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30),
        new_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30)
      )

      event = CommandEvent.create(statement, user: user, channel_type: :dm)
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/you can now use this id wherever/i)
      expect(embed.color).to eql(ESM::Color::Toast::GREEN)
    end

    it "should error (Minimum characters)" do
      statement = command.statement(
        server_id: server.server_id,
        old_territory_id: Faker::Alphanumeric.alphanumeric(number: 2),
        new_territory_id: Faker::Alphanumeric.alphanumeric(number: 2)
      )
      event = CommandEvent.create(statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /must be at least 3/i)
    end

    it "should error (Maximum characters)" do
      statement = command.statement(
        server_id: server.server_id,
        old_territory_id: Faker::Alphanumeric.alphanumeric(number: 31),
        new_territory_id: Faker::Alphanumeric.alphanumeric(number: 31)
      )
      event = CommandEvent.create(statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /cannot be longer than 30/i)
    end

    #
    it "should error (DLL Reason)" do
      request = nil
      statement = command.statement(
        server_id: server.server_id,
        old_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30),
        new_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30)
      )
      event = CommandEvent.create(statement, user: user, channel_type: :dm)

      wsc.flags.FAIL_WITH_REASON = true
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/some reason/i)
      expect(embed.color).to eql(ESM::Color::Toast::RED)
    end

    it "should error (Permission denied)" do
      request = nil
      statement = command.statement(
        server_id: server.server_id,
        old_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30),
        new_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30)
      )
      event = CommandEvent.create(statement, user: user, channel_type: :dm)

      wsc.flags.FAIL_WITHOUT_REASON = true
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(/you are not allowed to do that/i)
      expect(embed.color).to eql(ESM::Color::Toast::RED)
    end
  end
end
