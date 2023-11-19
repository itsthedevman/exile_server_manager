# frozen_string_literal: true

describe ESM::Websocket::Request::Overseer do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:user) { ESM::Test.user }
  let!(:connection) { WebsocketClient.new(server) }

  before do
    wait_for { connection.connected? }.to be(true)
  end

  after do
    connection.disconnect!
  end

  describe "Timeout Thread" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    let!(:server_connection) { ESM::Websocket.connections[server.server_id] }
    let!(:iterations) { Faker::Number.between(from: 1, to: 10) }

    before do
      iterations.times do
        server_connection.requests << ESM::Websocket::Request.new(user: nil, channel: nil, command_name: "testing", parameters: nil)
      end
    end

    it "should not time out" do
      expect(server_connection.requests.size).to eq(iterations)
      sleep(1)
      expect(server_connection.requests.size).to eq(iterations)
    end

    it "should remove the timed out request" do
      execute!

      server_connection.requests << ESM::Websocket::Request.new(user: user.discord_user, command: previous_command, channel: nil, parameters: nil, timeout: 0)

      expect(server_connection.requests.size).to eq(iterations + 1)
      sleep(1)
      expect(server_connection.requests.size).to eq(iterations)
      wait_for { ESM::Test.messages.size }.to eq(1)
      expect(ESM::Test.messages.first.content.description).to match(/never replied to your command/i)
    end
  end
end
