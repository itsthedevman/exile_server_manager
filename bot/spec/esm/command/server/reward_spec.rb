# frozen_string_literal: true

describe ESM::Command::Server::Reward, category: "command" do
  let!(:command) { ESM::Command::Server::Reward.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
    expect(command.arguments.size).to eql(1)
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

    it "!reward server_id" do
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second

      # Checks for requestors message
      expect(embed).not_to be_nil

      # Checks for requestees message
      expect(ESM::Test.messages.size).to eql(2)

      # Process the request
      request = command.request
      expect(request).not_to be_nil

      # Respond to the request
      request.respond(true)

      # Reset so we can track the response
      ESM::Test.reset!

      # Wait for the server to respond
      wait_for { connection.requests }.to be_blank

      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second

      reward = server.server_reward

      expect(embed.description).to include("#{reward.player_poptabs}x Poptabs (Player)") if reward.player_poptabs.positive?
      expect(embed.description).to include("#{reward.locker_poptabs}x Poptabs (Locker)") if reward.locker_poptabs.positive?
      expect(embed.description).to include("#{reward.respect}x Respect") if reward.respect.positive?

      reward.reward_items.each do |item, quantity|
        # Technically, the item should be converted to a proper display name by the server, but I don't have that ability here.
        expect(embed.description).to include("#{quantity}x #{item}")
      end
    end

    it "!reward server_id (Pending Request)" do
      command_statement = command.statement(server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      # Create a pending request
      ESM::Request.create!(
        requestor_user_id: user.id,
        requestee_user_id: user.id,
        requested_from_channel_id: event.channel.id,
        command_name: command.name,
        command_arguments: { server_id: server.server_id }
      )

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data

        expect(embed.description).to match(/it appears you already have a request pending/i)
      end
    end

    describe "No rewards" do
      before :each do
        server.server_reward = ESM::ServerReward.create!(server_id: server.id)
      end

      it "should error" do
        command_statement = command.statement(server_id: server.server_id)
        event = CommandEvent.create(command_statement, user: user, channel_type: :text)
        expect { command.execute(event) }.to raise_error do |error|
          embed = error.data
          expect(embed.description).to match(/it looks like this server does not have any rewards for you to redeem/i)
        end
      end
    end
  end
end
