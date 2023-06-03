# frozen_string_literal: true

describe ESM::Command::Base do
  include_context "connection"

  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:user) { ESM::Test.user }

  describe "Properties" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::BaseV1 }
    end

    it "has a valid name" do
      expect(command.name).to eq("base")
    end

    it "has a valid category" do
      expect(command.category).to eq("test")
    end

    it "has 2 aliases" do
      expect(command.aliases.size).to eq(2)
    end

    it "has #{ESM::Command::Test::BaseV1::ARGUMENT_COUNT} arguments" do
      expect(command.arguments.size).to eq(ESM::Command::Test::BaseV1::ARGUMENT_COUNT)
    end

    it "has description" do
      expect(command.description).to eq("A test command")
    end

    it "has a type" do
      expect(command.type).to eq(:player)
    end

    it "has an example" do
      expect(command.example).to eq("A test example")
    end

    it "has defines" do
      expect(command.defines).not_to be_nil
      expect(command.defines.enabled.modifiable).to be(true)
      expect(command.defines.enabled.default).to be(true)
      expect(command.defines.whitelist_enabled.modifiable).to be(true)
      expect(command.defines.whitelist_enabled.default).to eq(false)
      expect(command.defines.whitelisted_role_ids.modifiable).to be(true)
      expect(command.defines.whitelisted_role_ids.default).to eq([])
      expect(command.defines.allowed_in_text_channels.modifiable).to be(true)
      expect(command.defines.allowed_in_text_channels.default).to be(true)
      expect(command.defines.cooldown_time.modifiable).to be(true)
      expect(command.defines.cooldown_time.default).to eq(2.seconds)
    end

    it "has requires" do
      expect(command.requires).not_to be_nil
      expect(command.requires).to contain_exactly(:registration)
    end

    it "has proper usage" do
      expect(command.usage).to match(/.+base <community_id> <server_id> <target> <_integer> <_preserve> <sa_yalpsid> <\?_default> <\?_multiline>/i)
    end
  end

  describe "#create_user" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    it "creates an unregistered user" do
      execute!
      expect(ESM::User.all.size).to eq(1)
    end
  end

  describe "#current_user" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:current_user)).to be(true)
    end

    it "has a valid user" do
      execute!
      expect(command.current_user).not_to be_nil
      expect(command.current_user.id.to_s).to eq(user.discord_id)
    end

    it "creates" do
      discord_id = user.discord_id
      user.destroy

      execute!

      new_current_user = ESM::User.find_by_discord_id(discord_id)
      expect(new_current_user).not_to be(nil)
      expect(command.current_user.id.to_s).to eq(new_current_user.discord_id)
    end
  end

  describe "#current_community" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CommunityCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:current_community)).to be(true)
    end

    it "is a valid community" do
      execute!(community_id: community.community_id)
      expect(command.current_community).not_to be_nil
      expect(command.current_community.id).to eq(community.id)
    end
  end

  describe "#target_server" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::ServerCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:target_server)).to be(true)
    end

    it "is a valid server" do
      expect { execute!(fail_on_raise: false, server_id: server.server_id) }.to raise_error(ESM::Exception::CheckFailure)

      expect(command.target_server).not_to be_nil
      expect(command.target_server.id).to eq(server.id)
      expect(command.arguments.server_id).to eq(server.server_id)
    end

    it "is invalid" do
      expect { execute!(fail_on_raise: false, server_id: "esm_ This Server Cannot Exist") }.to raise_error(ESM::Exception::CheckFailure)
    end
  end

  describe "#target_community" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CommunityCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:target_community)).to be(true)
    end

    it "is a valid community" do
      execute!(community_id: community.community_id)

      expect(command.target_community).not_to be_nil
      expect(command.target_community.id).to eq(community.id)
    end

    it "is invalid" do
      expect { execute!(fail_on_raise: false, community_id: "es") }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data.description).to match(/hey .+, i was unable to find a community with an ID of `.+`./i)
      end
    end
  end

  describe "#target_user" do
    let!(:secondary_user) { ESM::Test.user }

    include_context "command" do
      let!(:command_class) { ESM::Command::Test::TargetCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:target_user)).to be(true)
    end

    it "is a valid user" do
      execute!(target: secondary_user.discord_id)
      expect(command.target_user).not_to be_nil
      expect(command.target_user.id.to_s).to eq(secondary_user.discord_id)
    end

    it "is invalid" do
      expect { execute!(fail_on_raise: false, target: "000000000000000000") }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "creates" do
      discord_id = secondary_user.discord_id
      secondary_user.destroy

      execute!(target: discord_id)

      new_target_user = ESM::User.find_by_discord_id(discord_id)
      expect(new_target_user).not_to be(nil)
      expect(command.target_user.id.to_s).to eq(new_target_user.discord_id)
    end
  end

  describe "#target_uid" do
    let!(:secondary_user) { ESM::Test.user }

    include_context "command" do
      let!(:command_class) { ESM::Command::Test::TargetCommand }
    end

    it "from Steam UID" do
      execute!(target: secondary_user.steam_uid)
      expect(command.target_uid).to eq(secondary_user.steam_uid)
    end

    it "from mention" do
      execute!(target: secondary_user.mention)
      expect(command.target_uid).to eq(secondary_user.steam_uid)
    end

    it "from discord ID" do
      execute!(target: secondary_user.discord_id)
      expect(command.target_uid).to eq(secondary_user.steam_uid)
    end

    it "from unregistered" do
      secondary_user.update(steam_uid: nil)

      execute!(target: secondary_user.mention)
      expect(command.target_uid).to eq(nil)
    end

    it "from gibberish" do
      expect { execute!(fail_on_raise: false, target: "000000000000000000") }.to raise_error(ESM::Exception::CheckFailure)
      expect(command.target_uid).to eq(nil)
    end
  end

  describe "#registration_required?" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::ServerCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:registration_required?)).to be(true)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    it "does not require registration" do
      command.requires.delete(:registration)
      expect(command.registration_required?).to be(false)
    end
  end

  describe "#on_execute" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:on_execute)).to be(true)
    end

    it "is callable" do
      expect(command.on_execute).to eq("on_execute")
    end
  end

  describe "#on_response" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::PlayerCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:on_response)).to be(true)
    end

    it "is callable" do
      expect(command.on_response(nil, nil)).to eq("on_response")
    end
  end

  describe "#execute" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::ServerSuccessCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:execute)).to be(true)
    end

    it "executes" do
      expect {
        execute!(fail_on_raise: false, server_id: server.server_id, nullable: true)
      }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "executes with nullable arguments" do
      expect {
        execute!(fail_on_raise: false, server_id: server.server_id)
      }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "switches to a v1 command for v1 servers" do
      wsc = WebsocketClient.new(server)
      wait_for { wsc.connected? }.to be(true)

      expect(
        execute!(fail_on_raise: false, server_id: server.server_id)
      ).to be_instance_of(ESM::Command::Test::ServerSuccessCommandV1)

      wsc.disconnect!
    end

    it "stays as a v2 command", requires_connection: true do
      expect(
        execute!(server_id: server.server_id)
      ).to be_instance_of(ESM::Command::Test::ServerSuccessCommand)

      wait_for { ESM::Test.messages }.not_to be_empty
    end

    describe "Handles Errors", :error_testing do
      it "send error (CheckFailure)" do
        test_command = ESM::Command::Test::DirectMessageCommand.new
        event = CommandEvent.create(test_command.statement, channel_type: :text, user: user)

        expect { test_command.execute(event, raise_error: false) }.not_to raise_error
        wait_for { ESM::Test.messages.size }.to eq(1)

        error = ESM::Test.messages.first.second
        expect(error.description).to eq("Hey #{user.mention}, this command can only be used in a **Direct Message** with me.\n\nJust right click my name, click **Message**, and send it there")
      end

      it "send error (StandardError)" do
        test_command = ESM::Command::Test::ErrorCommand.new
        event = CommandEvent.create(test_command.statement, channel_type: :text, user: user)

        expect { test_command.execute(event, raise_error: false) }.not_to raise_error
        wait_for { ESM::Test.messages.size }.to eq(1)

        error = ESM::Test.messages.first.second
        expect(error.description).to include("Well, this is awkward.\nWill you please join my Discord (https://esmbot.com/join) and let my developer know that this happened?\nPlease give him this code:\n```")
      end

      it "resets cooldown when an error occurs", requires_connection: true do
        command = ESM::Command::Test::ServerErrorCommand.new
        execute!(command: command, server_id: server.server_id)
        wait_for { ESM::Test.messages.size }.to eq(1)
        expect(command.current_cooldown.active?).to be(false)
      end
    end
  end

  describe "#check_failed!" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::BaseV1 }
    end

    it "raises the translation" do
      expect { command.check_failed!(:text_only, user: user.mention) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data

        expect(embed.description).to match(/this command can only be used in a discord server's \*\*text channel\*\*/i)
      end
    end

    it "raises the block" do
      expect { command.check_failed! { "This will is the message" } }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data).to match(/this will is the message/i)
      end
    end
  end

  describe "limit to" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::BaseV1 }
    end

    it "has no limit" do
      expect(command.limit_to).to be_nil
      expect(command.dm_only?).to be(false)
      expect(command.text_only?).to be(false)
    end

    it "is limited to DM" do
      command.limit_to = :dm
      expect(command.limit_to).to eq(:dm)
      expect(command.dm_only?).to be(true)
      expect(command.text_only?).to be(false)
      command.limit_to = nil
    end

    it "is limited to text" do
      command.limit_to = :text
      expect(command.limit_to).to eq(:text)
      expect(command.dm_only?).to be(false)
      expect(command.text_only?).to be(true)
      command.limit_to = nil
    end

    it "executes in both DM and Text channels", requires_connection: true do
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

    it "executes in only DM channels", requires_connection: true do
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

    it "executes in on Text channels", requires_connection: true do
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

  describe "#create_or_update_cooldown" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CooldownCommand }
    end

    it "creates a cooldown if one doesn't exist" do
      expect(ESM::Cooldown.all.size).to eq(0)
      execute!

      expect(command.current_cooldown).to be_kind_of(ESM::Cooldown)
      expect(command.current_cooldown.valid?).to be(true)
      expect(command.current_cooldown.persisted?).to be(true)
    end

    it "updates the cooldown if one exists" do
      cooldown = create(:cooldown, :inactive, user_id: user.id, community_id: community.id, command_name: command.name)
      execute!

      expect(command.current_cooldown).to be_kind_of(ESM::Cooldown)
      expect(command.current_cooldown.valid?).to be(true)
      expect(command.current_cooldown.persisted?).to be(true)
      expect(command.current_cooldown.id).to eq(cooldown.id)
    end
  end

  describe "#current_cooldown_query" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CooldownCommand }
    end

    let(:query_hash) { command.current_cooldown_query.where_values_hash.symbolize_keys }
    let!(:target_community) { ESM::Test.second_community }

    before do
      command.instance_variable_set(:@current_user, user.discord_user)
    end

    it "uses the user ID when registration is not required" do
      expect(query_hash).to include(
        command_name: command.name, user_id: user.id
      ).and exclude(
        :steam_uid, :server_id, :community_id
      )
    end

    it "uses the steam UID when registration is required" do
      command.instance_variable_set(:@requires, [:registration])

      expect(query_hash).to include(
        command_name: command.name, steam_uid: user.steam_uid
      ).and exclude(
        :user_id, :server_id, :community_id
      )
    end

    it "includes the target community's ID when one is provided" do
      command.instance_variable_set(:@current_community, community)
      command.instance_variable_set(:@target_community, target_community)

      expect(query_hash).to include(
        command_name: command.name, user_id: user.id, community_id: target_community.id
      ).and exclude(
        :steam_uid, :server_id
      )
    end

    it "includes the current community's ID when there is a current community but no target community" do
      command.instance_variable_set(:@current_community, community)

      expect(query_hash).to include(
        command_name: command.name, user_id: user.id, community_id: community.id
      ).and exclude(
        :steam_uid, :server_id
      )
    end

    it "includes the target server's ID when one is provided" do
      command.instance_variable_set(:@target_server, server)

      expect(query_hash).to include(
        command_name: command.name, user_id: user.id, server_id: server.id
      ).and exclude(
        :steam_uid
      )
    end
  end

  describe "#on_cooldown?" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CooldownCommand }
    end

    it "respond" do
      expect(command.respond_to?(:on_cooldown?)).to be(true)
    end

    it "is on cooldown" do
      cooldown = create(:cooldown, :active, user_id: user.id, community_id: community.id, command_name: command.name)
      expect { execute!(fail_on_raise: false) }.to raise_error(ESM::Exception::CheckFailure, /you're on cooldown/i)

      expect(command.current_cooldown).to eq(cooldown)
      expect(command.on_cooldown?).to be(true)
    end

    it "is not on cooldown" do
      create(:cooldown, :inactive, user_id: user.id, community_id: community.id, command_name: command.name)

      command.send(:skip, :cooldown)
      execute!(fail_on_raise: false)

      expect(command.on_cooldown?).to be(false)
    end
  end

  # V1
  describe "#deliver" do
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }

    before :each do
      wait_for { wsc.connected? }.to be(true)
    end

    after :each do
      wsc.disconnect!
    end

    it "raises" do
      server_command = ESM::Command::Test::ServerSuccessCommandV1.new
      event = CommandEvent.create(server_command.statement(server_id: nil), channel_type: :text, user: user)
      server_command.event = event

      expect { server_command.deliver! }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "delivers" do
      server_command = ESM::Command::Test::ServerSuccessCommandV1.new
      event = CommandEvent.create(server_command.statement(server_id: server.server_id), channel_type: :text, user: user)

      expect { server_command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      wait_for { ESM::Test.messages.size }.to eq(1)
    end
  end

  describe "#reply" do
    it "sends a message to channel" do
      server_command = ESM::Command::Test::ServerSuccessCommand.new
      event = CommandEvent.create(server_command.statement(server_id: server.server_id), channel_type: :text, user: user)
      server_command.event = event

      server_command.reply("Hello")
      wait_for { ESM::Test.messages.size }.to eq(1)

      message_array = ESM::Test.messages.first
      expect(message_array.first.id).to eq(event.channel.id)
      expect(message_array.second).to eq("Hello")
    end
  end

  # Truth table: https://docs.google.com/spreadsheets/d/1BDHVwhyvgbFPlXnAtFKzOcPtGhZ1zG5H-_1km3VXKr8/edit#gid=0
  describe "Command Permissions" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CommunityCommand }
    end

    let!(:configuration) { ESM::CommandConfiguration.where(command_name: command.name).first }
    let(:whitelisted_role_ids) { community.role_ids }

    describe "Text Channel" do
      describe "Allowed" do
        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: true" do
          configuration.update!(
            enabled: true,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: true
          )

          execute!(community_id: community.community_id)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: true
          )

          # CHECK THAT user ACTUALLY HAS ROLE
          execute!(send_as: role_user, community_id: community.community_id)
        end
      end

      describe "Denied" do
        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, notify_when_disabled: true" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: true
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, notify_when_disabled: false" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: false
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailureNoMessage)

          # It did not send a message
          expect(ESM::Test.messages.size).to eq(0)
        end

        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: true" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: true,
            whitelisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: false" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: false
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: true" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: true
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: false" do
          configuration.update!(
            enabled: true,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not allowed/i)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: false, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            whitelist_enabled: true,
            whitelisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(send_as: role_user, fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: false" do
          configuration.update!(
            enabled: true,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: false
          )

          expect {
            execute!(fail_on_raise: false, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end
      end
    end

    describe "Private Message" do
      describe "Allowed" do
        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: true" do
          configuration.update!(
            enabled: true,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: true
          )

          execute!(channel_type: :pm, community_id: community.community_id)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: true
          )

          execute!(send_as: role_user, channel_type: :pm, community_id: community.community_id)
        end

        it "enabled: true, whitelist_enabled: false, whitelisted: false, allowed: false" do
          configuration.update!(
            enabled: true,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: false
          )

          execute!(channel_type: :pm, community_id: community.community_id)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: true, allowed: false" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: false
          )

          execute!(send_as: role_user, channel_type: :pm, community_id: community.community_id)
        end
      end

      describe "Denied" do
        it "enabled: false, notify_when_disabled: true" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: true
          )

          expect {
            execute!(fail_on_raise: false, channel_type: :pm, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, notify_when_disabled: false" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: false
          )

          expect {
            execute!(fail_on_raise: false, channel_type: :pm, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(fail_on_raise: false, channel_type: :pm, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: false, whitelisted: false, allowed: true" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: false,
            whitelisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(fail_on_raise: false, channel_type: :pm, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: true,
            whitelisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(
              fail_on_raise: false,
              channel_type: :pm,
              send_as: user,
              community_id: community.community_id
            )
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: false" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: true,
            whitelisted_role_ids: community.role_ids,
            allowed_in_text_channels: false
          )

          expect {
            execute!(
              fail_on_raise: false,
              channel_type: :pm,
              send_as: user,
              community_id: community.community_id
            )
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, whitelist_enabled: true, whitelisted: true, allowed: true" do
          configuration.update!(
            enabled: false,
            whitelist_enabled: true,
            whitelisted_role_ids: whitelisted_role_ids,
            allowed_in_text_channels: true
          )

          expect {
            execute!(fail_on_raise: false, channel_type: :pm, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: true, whitelist_enabled: true, whitelisted: false, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            whitelist_enabled: true,
            whitelisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(fail_on_raise: false, send_as: role_user, channel_type: :pm, community_id: community.community_id)
          }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end
      end
    end
  end

  # Features of player mode:
  #   Use DM commands in Text Channels
  #   Run commands for OTHER community servers in text channels
  #   Blocks admin commands from being used text channels
  describe "Player Mode" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CommunityCommand }
    end

    let!(:player_community) { community }
    let(:server_community) { ESM::Test.second_community }

    before do
      player_community.update!(player_mode_enabled: true)
    end

    it "is enabled" do
      expect(player_community.player_mode_enabled?).to be(true)
    end

    it "is able to use DM only commands in text channel" do
      execute!(command: ESM::Command::Test::DirectMessageCommand.new)
    end

    it "is able to run player command for other communities in text channel" do
      # Ensure the command can still be used regardless of that communities permissions for "allowed_in_text_channels"
      player_community.command_configurations.where(command_name: command.name).first.update!(allowed_in_text_channels: false)

      execute!(community_id: server_community.community_id)
    end

    it "does not allow admin commands in text channel" do
      admin_only_command = ESM::Command::Test::AdminCommand.new

      expect {
        execute!(
          fail_on_raise: false,
          command: admin_only_command,
          community_id: server_community.community_id
        )
      }.to raise_error(ESM::Exception::CheckFailure, /is not available in player mode/i)

      expect {
        execute!(
          fail_on_raise: false,
          command: admin_only_command,
          community_id: player_community.community_id
        )
      }.to raise_error(ESM::Exception::CheckFailure, /is not available in player mode/i)
    end

    it "does not allow running commands for other communities in another server community's text channels" do
      expect {
        execute!(
          fail_on_raise: false,
          channel: ESM::Test.channel(in: server_community),
          community_id: player_community.community_id
        )
      }.to raise_error(ESM::Exception::CheckFailure, /commands for other communities/i)
    end
  end

  describe "#skip_check" do
    it "skips #check_for_connected_server!" do
      # Server is not connected here
      check_command = ESM::Command::Test::SkipServerCheckCommand.new
      event = CommandEvent.create(check_command.statement(server_id: server.server_id), channel_type: :text, user: user)
      expect { check_command.execute(event) }.not_to raise_error
    end
  end

  describe "#skip" do
    it "skips #create_or_update_cooldown" do
      skip_command = ESM::Command::Test::SkipCooldownCommand.new
      event = CommandEvent.create(skip_command.statement(server_id: server.server_id), channel_type: :text, user: user)
      expect { skip_command.execute(event) }.not_to raise_error
      expect(skip_command.current_cooldown).to eq(nil)
    end
  end

  describe "#add_request" do
    let!(:secondary_user) { ESM::Test.user }

    it "adds the request" do
      request_command = ESM::Command::Test::RequestCommand.new
      event = CommandEvent.create(request_command.statement(target: secondary_user.discord_id), channel_type: :text, user: user)
      expect { request_command.execute(event) }.not_to raise_error
      expect(ESM::Request.all.size).to eq(1)
      expect(secondary_user.pending_requests.size).to eq(1)
    end
  end

  describe "#from_request" do
    let!(:secondary_user) { ESM::Test.user }

    it "is accepted" do
      request_command = ESM::Command::Test::RequestCommand.new
      event = CommandEvent.create(request_command.statement(target: secondary_user.discord_id), channel_type: :text, user: user)
      expect { request_command.execute(event) }.not_to raise_error

      request = ESM::Request.first
      request.respond(true)

      wait_for { ESM::Test.messages.size }.to eq(2)
      expect(ESM::Test.messages.first.second).to be_a(ESM::Embed)
      expect(ESM::Test.messages.second.second).to eq("accepted")
    end

    it "is declined" do
      request_command = ESM::Command::Test::RequestCommand.new
      event = CommandEvent.create(request_command.statement(target: secondary_user.discord_id), channel_type: :text, user: user)
      expect { request_command.execute(event) }.not_to raise_error

      request = ESM::Request.first
      request.respond(false)

      wait_for { ESM::Test.messages.size }.to eq(2)
      expect(ESM::Test.messages.first.second).to be_a(ESM::Embed)
      expect(ESM::Test.messages.second.second).to eq("declined")
    end
  end
end
