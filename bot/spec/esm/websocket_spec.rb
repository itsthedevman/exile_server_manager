# frozen_string_literal: true

describe ESM::Websocket do
  # This test requires esm_community/esm_server
  let!(:esm_community) { create(:esm_community) }
  let!(:esm_malden) { create(:esm_malden, community_id: esm_community.id) }
  let!(:esm_malden_connection) { WebsocketClient.new(esm_malden) }

  before :each do
    wait_for { esm_malden_connection.connected? }.to be(true)
  end

  after :each do
    esm_malden_connection.disconnect!
  end

  it "should raise invalid key" do
    bad_ws = WebsocketClient.new(OpenStruct.new(server_key: "Nope!", server_id: "Nope!"))
    expect(bad_ws).not_to be_nil
    wait_for { bad_ws.connected? }.to be(false)
  end

  describe "Connections" do
    let!(:second_community) { create(:secondary_community) }
    let!(:second_server) { create(:server, community_id: second_community.id) }
    let!(:second_connection) { WebsocketClient.new(second_server) }

    before :each do
      wait_for { second_connection.connected? }.to be(true)
    end

    after :each do
      second_connection.disconnect!
    end

    it "should add" do
      expect(ESM::Websocket.connections[second_server.server_id]).not_to be_nil
    end

    it "should remove" do
      other_connection = ESM::Websocket.connections[second_server.server_id]

      expect(other_connection).not_to be_nil
      expect { ESM::Websocket.remove_connection(other_connection) }.not_to raise_error
      expect(ESM::Websocket.connections[second_server.server_id]).to be_nil
    end
  end

  describe "#deliver!" do
    it "should deliver" do
      user = ESM.bot.user(ESM::User::Bryan::ID)
      command = ESM::Command::Test::Base.new
      request = ESM::Websocket.deliver!(
        esm_malden.server_id,
        command: command,
        user: user,
        parameters: { foo: "Foo", bar: ["Bar"], baz: false }
      )

      expect(request).not_to be_nil
    end
  end

  describe "#correct" do
    it "should provide no corrections" do
      server = ESM::Server.all.sample(1).first
      correction = ESM::Websocket.correct(server.server_id)

      expect(correction).to be_blank
    end

    it "should provide a correction" do
      server = ESM::Server.all.sample(1).first
      correction = ESM::Websocket.correct(server.server_id[0..-3])

      expect(correction).not_to be_blank
      expect(correction.first).to eql(server.server_id)
    end
  end

  describe "#on_message" do
    let!(:user) { create(:user) }
    let!(:ws_connection) { ESM::Websocket.connections[esm_malden.server_id] }
    let!(:event) { CommandEvent.create(ESM::Command::Test::Base::COMMAND_FULL, user: user) }
    let!(:channel) { ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL) }
    let!(:discord_user) { user.discord_user }

    let!(:command) do
      command = ESM::Command::Test::Base.new

      # Execute the command to set up all of the required variables
      expect { command.execute(event) }.not_to raise_error
      command
    end

    let!(:request) do
      ws_connection.send(
        :add_request,
        command: command,
        user: discord_user,
        channel: channel,
        parameters: [],
        timeout: 5
      )
    end

    # Ignored commands do not remove the request.
    it "should handle ignored requests" do
      message = {
        commandID: request.id,
        ignore: true
      }.to_json

      expect(ws_connection.requests.size).to eql(1)
      ws_connection.send(:on_message, OpenStruct.new(data: message))
      expect(ws_connection.requests.size).to eql(1)
    end

    it "should send an error message (error)" do
      message = {
        commandID: request.id,
        error: Faker::Lorem.sentence
      }.to_json

      ws_connection.send(:on_message, OpenStruct.new(data: message))

      message = message.to_ostruct
      expect(ESM::Test.messages.size).to eql(1)
      error_message = ESM::Test.messages.first.second

      expect(error_message).not_to be_nil
      expect(error_message.description).to eql("#{discord_user.mention}, #{message.error}")
      expect(error_message.color).to eql("#C62551")
    end

    it "should send an error message (parameters)" do
      message = {
        commandID: request.id,
        parameters: [{
          error: Faker::Lorem.sentence
        }]
      }.to_json

      ws_connection.send(:on_message, OpenStruct.new(data: message))

      message = message.to_ostruct
      expect(ESM::Test.messages.size).to eql(1)
      error_message = ESM::Test.messages.first.second

      expect(error_message).not_to be_nil
      expect(error_message.description).to eql("#{discord_user.mention}, #{message.parameters.first.error}")
      expect(error_message.color).to eql("#C62551")
    end
  end
end
