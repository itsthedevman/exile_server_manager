# frozen_string_literal: true

describe ESM::Command::Server::Player, category: "command" do
  let!(:command) { ESM::Command::Server::Player.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 4 argument" do
    expect(command.arguments.size).to eq(4)
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
    let!(:second_user) { ESM::Test.user }

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)

      grant_command_access!(community, "player")
    end

    after :each do
      wsc.disconnect!
    end

    it "!player money" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "money", value: Faker::Number.between(from: -500, to: 500))
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s money by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
    end

    it "!player m" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "m", value: Faker::Number.between(from: -500, to: 500))
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s money by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
    end

    it "!player locker" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "locker", value: Faker::Number.between(from: -500, to: 500))
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s locker by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
    end

    it "!player l" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "l", value: Faker::Number.between(from: -500, to: 500))
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s locker by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
    end

    it "!player respect" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "respect", value: Faker::Number.between(from: -500, to: 500))
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s respect by #{response.modified_amount.to_readable} points. They used to have #{response.previous_amount.to_readable}, they now have #{response.new_amount.to_readable}.")
    end

    it "!player r" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "r", value: Faker::Number.between(from: -500, to: 500))
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s respect by #{response.modified_amount.to_readable} points. They used to have #{response.previous_amount.to_readable}, they now have #{response.new_amount.to_readable}.")
    end

    it "!player heal" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "heal")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).not_to be_blank
    end

    it "!player h" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "h")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).not_to be_blank
    end

    it "!player kill" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "kill")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).not_to be_blank
    end

    it "!player k" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "k")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).not_to be_blank
    end

    it "should require a value" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "money")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::FailedArgumentParse)
    end

    it "should work with a non-registered steam uid" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(server_id: server.server_id, target: steam_uid, type: "h")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).not_to be_blank
    end

    it "sets the default value to nil if the type is kill or heal" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "k", value: 55)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      expect(command.arguments.value).to be_nil

      # Since we just executed the command
      command.current_cooldown.reset!

      command_statement = command.statement(server_id: server.server_id, target: second_user.mention, type: "h", value: 55)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      expect(command.arguments.value).to be_nil
    end

    # Ensures the `before_store` does not cause a crash due to the change to how arguments are parsed.
    it "displays missing argument" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::FailedArgumentParse)
    end
  end
end
