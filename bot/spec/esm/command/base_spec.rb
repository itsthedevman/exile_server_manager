# frozen_string_literal: true

describe ESM::Command::Base do
  # NOTE: This command REQUIRES esm_community, an esm server, AND a user in ESM.
  # Bryan - You've tried 3 times to change that. Stop trying to make that work. :P
  let!(:command) { ESM::Command::Test::Base.new }
  let!(:community) { create(:esm_community) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }
  let!(:configuration) { community.command_configurations.where(command_name: "base").first }
  let(:wsc) { WebsocketClient.new(server) }
  let(:connection) { ESM::Websocket.connections[server.server_id] }

  it "should have a valid name" do
    expect(command.name).to eql("base")
  end

  it "should have a valid category" do
    expect(command.category).to eql("test")
  end

  it "should have 2 aliases" do
    expect(command.aliases.size).to eql(2)
  end

  it "should have #{ESM::Command::Test::Base::ARGUMENT_COUNT} arguments" do
    expect(command.arguments.size).to eql(ESM::Command::Test::Base::ARGUMENT_COUNT)
  end

  it "should have description" do
    expect(command.description).to eql("A test command")
  end

  it "should have a type" do
    expect(command.type).to eql(:player)
  end

  it "should have an example" do
    expect(command.example).to eql("A test example")
  end

  it "should have defines" do
    expect(command.defines).not_to be_nil
    expect(command.defines.enabled.modifiable).to be(true)
    expect(command.defines.enabled.default).to be(true)
    expect(command.defines.whitelist_enabled.modifiable).to be(true)
    expect(command.defines.whitelist_enabled.default).to eql(false)
    expect(command.defines.whitelisted_role_ids.modifiable).to be(true)
    expect(command.defines.whitelisted_role_ids.default).to eql([])
    expect(command.defines.allowed_in_text_channels.modifiable).to be(true)
    expect(command.defines.allowed_in_text_channels.default).to be(true)
    expect(command.defines.cooldown_time.modifiable).to be(true)
    expect(command.defines.cooldown_time.default).to eql(2.seconds)
  end

  it "should have requires" do
    expect(command.requires).not_to be_nil
    expect(command.requires).to contain_exactly(:registration)
  end

  it "should have proper usage" do
    expect(command.usage).to match(/.+base <community_id> <server_id> <target> <_integer> <_preserve> <sa_yalpsid> <\?_default> <\?_multiline>/i)
  end

  # Due to the way discordrb caches users, this needs to be at the top
  describe "#create_user" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should create an unregistered user" do
      ESM::User.destroy_all
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as",
        _default: "default",
        _multiline: "multi\nline"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)
      expect(ESM::User.all.size).to eql(1)
    end
  end

  describe "#current_user" do
    let!(:secondary_user) { create(:secondary_user) }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should be defined" do
      expect(command.respond_to?(:current_user)).to be(true)
    end

    it "should have a valid user" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
      expect(command.current_user).not_to be_nil
      expect(command.current_user.id).to eql(event.user.id)
    end

    it "should create" do
      discord_id = user.discord_id

      # Remove the user, this should recreate
      user.delete

      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)
      new_current_user = ESM::User.find_by_discord_id(discord_id)
      expect(new_current_user).not_to be(nil)
      expect(command.current_user.id.to_s).to eql(new_current_user.discord_id)
    end
  end

  describe "#current_community" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should be defined" do
      expect(command.respond_to?(:current_community)).to be(true)
    end

    it "should be a valid community" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
      expect(command.current_community).not_to be_nil
      expect(command.current_community.id).to eql(community.id)
    end
  end

  describe "#target_server" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should be defined" do
      expect(command.respond_to?(:target_server)).to be(true)
    end

    it "should be a valid server" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
      expect(command.target_server).not_to be_nil
      expect(command.target_server.id).to eql(server.id)
      expect(command.arguments.server_id).to eql(server.server_id)
    end

    it "should be invalid" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: "esm_mal",
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)
    end
  end

  describe "#target_community" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should be defined" do
      expect(command.respond_to?(:target_community)).to be(true)
    end

    it "should be a valid community" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
      expect(command.target_community).not_to be_nil
      expect(command.target_community.id).to eql(community.id)
    end

    it "should be invalid" do
      command_statement = command.statement(
        community_id: "es",
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data.description).to match(/hey .+, i was unable to find a community with an ID of `.+`./i)
      end
    end
  end

  describe "#target_user" do
    let!(:secondary_user) { create(:secondary_user) }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should be defined" do
      expect(command.respond_to?(:target_user)).to be(true)
    end

    it "should be a valid user" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
      expect(command.target_user).not_to be_nil
      expect(command.target_user.id.to_s).to eql(secondary_user.discord_id)
    end

    it "should be invalid" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: "000000000000000000",
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "should create" do
      discord_id = secondary_user.discord_id

      # Remove the user, this should recreate
      secondary_user.delete

      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)

      expect { command.execute(event) }.not_to raise_error
      new_target_user = ESM::User.find_by_discord_id(discord_id)
      expect(new_target_user).not_to be(nil)
      expect(command.target_user.id.to_s).to eql(new_target_user.discord_id)
    end
  end

  describe "#target_uid" do
    let!(:secondary_user) { create(:secondary_user) }

    before :each do
      user.update(steam_uid: ESM::User::Bryan::STEAM_UID)
      secondary_user.update(steam_uid: ESM::User::BryanV2::STEAM_UID)
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "from Steam UID" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.steam_uid,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(command.target_uid).to eql(secondary_user.steam_uid)
    end

    it "from mention" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.mention,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(command.target_uid).to eql(secondary_user.steam_uid)
    end

    it "from discord ID" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(command.target_uid).to eql(secondary_user.steam_uid)
    end

    it "from unregistered" do
      secondary_user.update(steam_uid: nil)

      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: secondary_user.mention,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(command.target_uid).to eql(nil)
    end

    it "from gibberish" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: "000000000000000000",
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)

      expect(command.target_uid).to eql(nil)
    end
  end

  describe "#registration_required?" do
    it "should be defined" do
      expect(command.respond_to?(:registration_required?)).to be(true)
    end

    it "should require registration" do
      expect(command.registration_required?).to be(true)
    end

    it "should not require registration" do
      command.requires.delete(:registration)
      expect(command.registration_required?).to be(false)
    end
  end

  describe "#discord" do
    it "should be defined" do
      expect(command.respond_to?(:discord)).to be(true)
    end

    it "should be callable" do
      expect(command.discord).to eql("discord")
    end
  end

  describe "#server" do
    it "should be defined" do
      expect(command.respond_to?(:server)).to be(true)
    end

    it "should be callable" do
      expect(command.server).to eql("server")
    end
  end

  describe "#execute" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should be defined" do
      expect(command.respond_to?(:execute)).to be(true)
    end

    it "should execute" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as",
        _default: "default",
        _multiline: "multi\nline"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
    end

    it "should execute with nullable arguments" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error
    end

    it "should reset cooldown if errored" do
      request = nil
      server_command = ESM::Command::Test::ServerErrorCommand.new
      event = CommandEvent.create(server_command.statement(server_id: server.server_id), channel_type: :text, user: user)

      expect { request = server_command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
      expect(server_command.current_cooldown.active?).to be(false)
    end

    describe "Handle Error" do
      before :all do
        # Change the ENV for ESM so the error won't be raised
        ESM.instance_variable_set("@env", ActiveSupport::StringInquirer.new("error_testing"))
      end

      after :all do
        # Reset!
        ESM.instance_variable_set("@env", ActiveSupport::StringInquirer.new("test"))
      end

      it "should send error (CheckFailure)" do
        test_command = ESM::Command::Test::DirectMessageCommand.new
        event = CommandEvent.create(test_command.statement, channel_type: :text, user: user)

        expect { test_command.execute(event) }.not_to raise_error
        expect(ESM::Test.messages.size).to eql(1)

        error = ESM::Test.messages.first.second
        expect(error.description).to eql("Hey #{user.mention}, this command can only be used in a **Direct Message** with me.\n\nJust right click my name, click **Message**, and send it there")
      end

      it "should send error (StandardError)" do
        test_command = ESM::Command::Test::ErrorCommand.new
        event = CommandEvent.create(test_command.statement, channel_type: :text, user: user)

        expect { test_command.execute(event) }.not_to raise_error
        expect(ESM::Test.messages.size).to eql(1)

        error = ESM::Test.messages.first.second
        expect(error).to eql("Well, this is awkward. Can you let my developer know that something bad happened?\nGive him this error:\n```Oops```")
      end
    end
  end

  describe "#check_failed!" do
    it "should raise the translation" do
      expect { command.check_failed!(:text_only, user: user.mention) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data

        expect(embed.description).to match(/this command can only be used in a discord server's \*\*text channel\*\*/i)
      end
    end

    it "should raise the block" do
      expect { command.check_failed! { "This will be the message" } }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data).to match(/this will be the message/i)
      end
    end
  end

  describe "limit to" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should have no limit" do
      expect(command.limit_to).to be_nil
      expect(command.dm_only?).to be(false)
      expect(command.text_only?).to be(false)
    end

    it "should be limited to DM" do
      command.limit_to = :dm
      expect(command.limit_to).to eql(:dm)
      expect(command.dm_only?).to be(true)
      expect(command.text_only?).to be(false)
      command.limit_to = nil
    end

    it "should be limited to text" do
      command.limit_to = :text
      expect(command.limit_to).to eql(:text)
      expect(command.dm_only?).to be(false)
      expect(command.text_only?).to be(true)
      command.limit_to = nil
    end

    it "should execute in both DM and Text channels" do
      ESM::Test.skip_cooldown = true
      command.limit_to = nil

      # Test text channel
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :text, user: user)
      expect { command.execute(event) }.not_to raise_error

      # Test dm channel
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :dm, user: user)
      expect { command.execute(event) }.not_to raise_error
    end

    it "should execute in only DM channels" do
      ESM::Test.skip_cooldown = true
      command.limit_to = :dm

      # Test text channel
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :text, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data
        expect(embed.description).to match(/this command can only be used in a \*\*direct message\*\* with me/i)
      end

      # Test dm channel
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :dm, user: user)
      expect { command.execute(event) }.not_to raise_error

      command.limit_to = nil
    end

    it "should execute in on Text channels" do
      ESM::Test.skip_cooldown = true
      command.limit_to = :text

      # Test text channel
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :text, user: user)
      expect { command.execute(event) }.not_to raise_error

      # Test dm channel
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :dm, user: user)
      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data
        expect(embed.description).to match(/this command can only be used in a discord server's \*\*text channel\*\*\./i)
      end

      command.limit_to = nil
    end
  end

  describe "#next_expiry" do
    it "should respond" do
      expect(command.respond_to?(:next_expiry)).to be(true)
    end

    it "should be valid" do
      time = DateTime.now
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, channel_type: :text, user: user)

      # I don't care what happens
      command.execute(event) rescue nil # rubocop:disable Style/RescueModifier

      # Override the execution_time
      command.executed_at = time

      expect(command.executed_at.to_s).to eql(time.to_s)
      expect(command.next_expiry.to_s).to eql((time + command.permissions.cooldown_time).to_s)
    end
  end

  describe "#create_or_update_cooldown" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should add" do
      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as"
      )
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      expect(command.current_cooldown).to be_kind_of(ESM::Cooldown)
      expect(command.current_cooldown.valid?).to be(true)
      expect(command.current_cooldown.persisted?).to be(true)
    end
  end

  describe "#on_cooldown?" do
    it "should respond" do
      expect(command.respond_to?(:on_cooldown?)).to be(true)
    end

    it "should be on cooldown" do
      create(:cooldown, :active, user_id: user.id, community_id: community.id)

      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as",
        _default: "default",
        _multiline: "multi\nline"
      )
      event = CommandEvent.create(command_statement, user: user)
      command.event = event

      expect(command.on_cooldown?).to be(true)
    end

    it "should not be on cooldown" do
      create(:cooldown, :inactive, user_id: user.id, community_id: community.id)

      command_statement = command.statement(
        community_id: community.community_id,
        server_id: server.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_as",
        _default: "default",
        _multiline: "multi\nline"
      )
      event = CommandEvent.create(command_statement, user: user)
      command.event = event

      expect(command.on_cooldown?).to be(false)
    end
  end

  describe "#deliver" do
    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "should raise" do
      server_command = ESM::Command::Test::ServerSuccessCommand.new
      event = CommandEvent.create(server_command.statement(server_id: nil), channel_type: :text, user: user)
      server_command.event = event

      expect { server_command.deliver! }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "should deliver" do
      request = nil
      server_command = ESM::Command::Test::ServerSuccessCommand.new
      event = CommandEvent.create(server_command.statement(server_id: server.server_id), channel_type: :text, user: user)

      expect { request = server_command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eql(1)
    end
  end

  describe "#reply" do
    it "should send a message to channel" do
      server_command = ESM::Command::Test::ServerSuccessCommand.new
      event = CommandEvent.create(server_command.statement(server_id: server.server_id), channel_type: :text, user: user)
      server_command.event = event

      server_command.reply("Hello")
      expect(ESM::Test.messages.size).to eql(1)

      message_array = ESM::Test.messages.first
      expect(message_array.first.id).to eql(event.channel.id)
      expect(message_array.second).to eql("Hello")
    end
  end

  # Truth table: https://docs.google.com/spreadsheets/d/1BDHVwhyvgbFPlXnAtFKzOcPtGhZ1zG5H-_1km3VXKr8/edit#gid=0
  describe "Command Permissions" do
    let(:user_with_role) { create(:andrew) }
    let(:whitelisted_role_ids) { ["424348476827238402"] }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    describe "Text Channel" do
      describe "Allowed" do
        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user)
          configuration.update(enabled: true, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: true)

          expect { command.execute(event) }.not_to raise_error
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user_with_role)
          configuration.update(enabled: true, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: true)

          expect { command.execute(event) }.not_to raise_error
        end
      end

      describe "Denied" do
        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user)
          configuration.update(enabled: false, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user)
          configuration.update(enabled: false, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: true)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: false, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user)
          configuration.update(enabled: false, whitelist_enabled: true, whitelisted_role_ids: [], allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user_with_role)
          configuration.update(enabled: false, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user_with_role)
          configuration.update(enabled: false, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: true)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user)
          configuration.update(enabled: true, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not allowed/i)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: false, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user)
          configuration.update(enabled: true, whitelist_enabled: true, whitelisted_role_ids: [], allowed_in_text_channels: true)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, user: user_with_role)
          configuration.update(enabled: true, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not allowed/i)
        end
      end
    end

    describe "Private Message" do
      describe "Allowed" do
        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user)
          configuration.update(enabled: true, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: true)

          expect { command.execute(event) }.not_to raise_error
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user_with_role)
          configuration.update(enabled: true, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: true)

          expect { command.execute(event) }.not_to raise_error
        end

        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user)
          configuration.update(enabled: true, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: false)

          expect { command.execute(event) }.not_to raise_error
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user_with_role)
          configuration.update(enabled: true, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: false)

          expect { command.execute(event) }.not_to raise_error
        end
      end

      describe "Denied" do
        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user)
          configuration.update(enabled: false, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user)
          configuration.update(enabled: false, whitelist_enabled: false, whitelisted_role_ids: [], allowed_in_text_channels: true)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: false, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user)
          configuration.update(enabled: false, whitelist_enabled: true, whitelisted_role_ids: [], allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: false" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user_with_role)
          configuration.update(enabled: false, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: false)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user_with_role)
          configuration.update(enabled: false, whitelist_enabled: true, whitelisted_role_ids: whitelisted_role_ids, allowed_in_text_channels: true)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: false, allowed: true" do
          command_statement = command.statement(
            community_id: community.community_id,
            server_id: server.server_id,
            target: user.discord_id,
            _integer: "1",
            _preserve: "PRESERVE",
            _display_as: "display_as",
            _default: "default",
            _multiline: "multi\nline"
          )
          event = CommandEvent.create(command_statement, channel_type: :pm, user: user)
          configuration.update(enabled: true, whitelist_enabled: true, whitelisted_role_ids: [], allowed_in_text_channels: true)

          expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end
      end
    end
  end

  # Features of player mode:
  #   Use DM commands in Text Channels
  #   Run commands for OTHER community servers in text channels
  #   Blocks admin commands from being used text channels
  describe "Player Mode" do
    let!(:secondary_community) { create(:secondary_community, :player_mode_enabled) }
    let!(:secondary_user) { create(:secondary_user) }

    it "should be enabled" do
      expect(secondary_community.player_mode_enabled?).to be(true)
    end

    it "should be able to use DM only commands in text channel" do
      dm_only_command = ESM::Command::Test::DirectMessageCommand.new
      event = CommandEvent.create(dm_only_command.statement, channel_type: :text, user: secondary_user)

      expect { dm_only_command.execute(event) }.not_to raise_error
    end

    it "should be able to run command for other communities in text channel" do
      community_command = ESM::Command::Test::CommunityCommand.new
      command_statement = community_command.statement(community_id: community.community_id)
      event = CommandEvent.create(command_statement, channel_type: :text, user: secondary_user)

      expect { community_command.execute(event) }.not_to raise_error
    end

    it "should not allow admin commands in text channel" do
      admin_only_command = ESM::Command::Test::AdminCommand.new
      command_statement = admin_only_command.statement(community_id: secondary_community.community_id)
      event = CommandEvent.create(command_statement, channel_type: :text, user: secondary_user)

      expect { admin_only_command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /is not available in player mode/i)
    end

    it "should not allow running commands for other communities in text channels" do
      community_command = ESM::Command::Test::CommunityCommand.new
      command_statement = community_command.statement(community_id: secondary_community.community_id)

      # `User` is executing this command from `community`.
      event = CommandEvent.create(command_statement, channel_type: :text, user: user)

      expect { community_command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /commands for other communities/i)
    end
  end

  describe "#skip_check" do
    it "should skip #check_for_connected_server!" do
      # Server is not connected here
      check_command = ESM::Command::Test::SkipServerCheckCommand.new
      event = CommandEvent.create(check_command.statement(server_id: server.server_id), channel_type: :text, user: user)
      expect { check_command.execute(event) }.not_to raise_error
    end
  end

  describe "#skip" do
    it "should skip #create_or_update_cooldown" do
      skip_command = ESM::Command::Test::SkipCooldownCommand.new
      event = CommandEvent.create(skip_command.statement(server_id: server.server_id), channel_type: :text, user: user)
      expect { skip_command.execute(event) }.not_to raise_error
      expect(skip_command.current_cooldown).to eql(nil)
    end
  end

  describe "#add_request" do
    let!(:secondary_user) { create(:secondary_user) }

    it "should add the request" do
      request_command = ESM::Command::Test::RequestCommand.new
      event = CommandEvent.create(request_command.statement(target: secondary_user.discord_id), channel_type: :text, user: user)
      expect { request_command.execute(event) }.not_to raise_error
      expect(ESM::Request.all.size).to eql(1)
      expect(secondary_user.pending_requests.size).to eql(1)
    end
  end

  describe "#from_request" do
    let!(:secondary_user) { create(:secondary_user) }

    it "should be accepted" do
      request_command = ESM::Command::Test::RequestCommand.new
      event = CommandEvent.create(request_command.statement(target: secondary_user.discord_id), channel_type: :text, user: user)
      expect { request_command.execute(event) }.not_to raise_error

      request = ESM::Request.first
      request.respond(true)
      expect(ESM::Test.messages.size).to eql(1)
      expect(ESM::Test.messages.first.second).to eql("accepted")
    end

    it "should be declined" do
      request_command = ESM::Command::Test::RequestCommand.new
      event = CommandEvent.create(request_command.statement(target: secondary_user.discord_id), channel_type: :text, user: user)
      expect { request_command.execute(event) }.not_to raise_error

      request = ESM::Request.first
      request.respond(false)
      expect(ESM::Test.messages.size).to eql(1)
      expect(ESM::Test.messages.first.second).to eql("declined")
    end
  end
end
