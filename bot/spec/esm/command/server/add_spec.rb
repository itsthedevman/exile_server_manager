# frozen_string_literal: true

describe ESM::Command::Server::Add, category: "command" do
  let!(:command) { ESM::Command::Server::Add.new }

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
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should not allow an unregistered user" do
      second_user.update(steam_uid: nil)
      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: Faker::Crypto.md5[0, 5],
        target: second_user.mention
      )

      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data
        expect(embed.description).to match(/has not registered with me yet. tell them to head over/i)
      end
    end

    it "should add (Different user)" do
      embed = nil
      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: Faker::Crypto.md5[0, 5],
        target: second_user.mention
      )

      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { embed = command.execute(event) }.not_to raise_error

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message
      expect(ESM::Test.messages.size).to eql(1)

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Respond to the request
      request.respond(true)

      # Reset so we can track the response
      ESM::Test.reset!

      # Wait for the server to respond
      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(2)
    end

    it "should add (Same user / Territory Admin)" do
      command_statement = command.statement(server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5], target: user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(0)

      # We don't create a request for this
      expect(ESM::Request.all.size).to eql(0)

      # Reset so we can track the response
      ESM::Test.reset!

      # Wait for the server to respond
      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(1)
    end
  end
end
