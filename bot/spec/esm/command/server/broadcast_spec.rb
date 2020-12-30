# frozen_string_literal: true

describe ESM::Command::Server::Broadcast, category: "command" do
  let!(:command) { ESM::Command::Server::Broadcast.new }

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
    let!(:second_server) { create(:server, community_id: community.id) }
    let!(:user) { ESM::Test.user }
    let!(:second_user) { ESM::Test.second_user }
    let!(:wsc) { WebsocketClient.new(server) }
    let!(:second_wsc) { WebsocketClient.new(second_server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? && second_wsc.connected? }.to be(true)

      # Create cooldowns for the users
      ESM::Cooldown.create!(user_id: user.id, community_id: community.id, server_id: server.id, command_name: "preferences", cooldown_type: "seconds", cooldown_quantity: 2)
      ESM::Cooldown.create!(user_id: user.id, community_id: community.id, server_id: second_server.id, command_name: "preferences", cooldown_type: "seconds", cooldown_quantity: 2)
      ESM::Cooldown.create!(user_id: second_user.id, community_id: community.id, server_id: second_server.id, command_name: "preferences", cooldown_type: "seconds", cooldown_quantity: 2)

      grant_command_access!(community, "broadcast")
    end

    after :each do
      wsc.disconnect!
      second_wsc.disconnect!
    end

    it "should send message to users on server" do
      command_statement = command.statement(broadcast_to: server.server_id, message: "Hello world!")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error

      # 1: Preview Message
      # 2: Spacer
      # 3: Confirmation
      # 4: Success message
      # 5: Message to first user
      expect(ESM::Test.messages.size).to eql(5)
    end

    it "should send message to users on all servers" do
      command_statement = command.statement(broadcast_to: "all", message: "Hello world!")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error

      # 1: Preview Message
      # 2: Spacer
      # 3: Confirmation
      # 4: Success message
      # 5: Message to first user
      # 6: Message to second user
      expect(ESM::Test.messages.size).to eql(6)
    end

    it "should preview the message" do
      command_statement = command.statement(broadcast_to: "preview", message: "Hello world!")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error

      # 1: Preview Message
      expect(ESM::Test.messages.size).to eql(1)
    end

    it "should not send the message" do
      command_statement = command.statement(broadcast_to: "all", message: "Hello world!")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "no"
      expect { command.execute(event) }.not_to raise_error

      # 1: Preview Message
      # 2: Spacer
      # 3: Confirmation
      # 4: Cancel message
      expect(ESM::Test.messages.size).to eql(4)
    end

    it "should accept a partial server_id" do
      command_statement = command.statement(
        broadcast_to: server.server_id[(community.community_id.size + 1)..],
        message: "Hello world!"
      )

      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error

      # 1: Preview Message
      # 2: Spacer
      # 3: Confirmation
      # 4: Success message
      # 5: Message to first user
      expect(ESM::Test.messages.size).to eql(5)
    end
  end
end
