# frozen_string_literal: true

describe ESM::Websocket::Request::Overseer do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }
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

    it "does not time out" do
      expect(server_connection.requests.size).to eq(iterations)
      sleep(1)
      expect(server_connection.requests.size).to eq(iterations)
    end

    it "removes the timed out request" do
      execute!

      server_connection.requests << ESM::Websocket::Request.new(user: user.discord_user, command: previous_command, channel: nil, parameters: nil, timeout: 0)

      expect(server_connection.requests.size).to eq(iterations + 1)
      sleep(1)
      expect(server_connection.requests.size).to eq(iterations)
      ESM.discord_bot.test_outbox.await_size(1)
      expect(ESM.discord_bot.test_outbox.first.content.description).to match(/never replied to your command/i)
    end
  end
end
