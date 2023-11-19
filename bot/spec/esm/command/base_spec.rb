# frozen_string_literal: true

describe ESM::Command::Base do
  include_context "connection"

  describe "Properties" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::BaseV1 }
    end

    it "has a valid name" do
      expect(command.command_name).to eq("base_v1")
    end

    it "has a valid category" do
      expect(command.category).to eq("test")
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

    it "has examples (hash)" do
      expect(command.examples(raw: true)).to eq(
        [{description: "A test example"}, {description: "An example with args", arguments: {target: "foo"}}]
      )
    end

    it "has examples (string)" do
      expect(command.examples).to eq(
        <<~STRING
          ```
          /test base_v1 community_id:<community> server_id:<server> target:<target>
          ```A test example

          ```
          /test base_v1 community_id:<community> server_id:<server> target:foo
          ```An example with args
        STRING
      )
    end

    it "has defines" do
      expect(command.attributes).not_to be_nil
      expect(command.attributes.enabled.modifiable).to be(true)
      expect(command.attributes.enabled.default).to be(true)
      expect(command.attributes.allowlist_enabled.modifiable).to be(true)
      expect(command.attributes.allowlist_enabled.default).to eq(false)
      expect(command.attributes.allowlisted_role_ids.modifiable).to be(true)
      expect(command.attributes.allowlisted_role_ids.default).to eq([])
      expect(command.attributes.allowed_in_text_channels.modifiable).to be(true)
      expect(command.attributes.allowed_in_text_channels.default).to be(true)
      expect(command.attributes.cooldown_time.modifiable).to be(true)
      expect(command.attributes.cooldown_time.default).to eq(2.seconds)
    end

    it "has requires" do
      expect(command.requirements).not_to be_nil
      expect(command.requirements).to contain_exactly(:registration)
    end

    it "has proper usage" do
      expect(command.usage).to eq("/test base_v1")
      expect(command.usage(use_placeholders: true)).to eq("/test base_v1 community_id:<community> server_id:<server> target:<target>")
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
      expect(previous_command.current_user).not_to be_nil
      expect(previous_command.current_user.discord_id).to eq(user.discord_id)
    end

    it "creates" do
      discord_id = user.discord_id
      user.destroy!

      expect { execute! }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data

        expect(embed.description).to match("I'll need you to link your Steam account")
      end

      new_current_user = ESM::User.find_by_discord_id(discord_id)
      expect(new_current_user).not_to be(nil)
      expect(previous_command.current_user.discord_id).to eq(new_current_user.discord_id)
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
      expect(previous_command.current_community).not_to be_nil
      expect(previous_command.current_community.id).to eq(community.id)
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
      expect { execute!(arguments: {server_id: server.server_id}) }.to raise_error(ESM::Exception::CheckFailure)

      expect(previous_command.target_server).not_to be_nil
      expect(previous_command.target_server.id).to eq(server.id)
      expect(previous_command.arguments.server_id).to eq(server.server_id)
    end

    it "is invalid" do
      expect { execute!(arguments: {server_id: "esm_ This Server Cannot Exist"}) }.to raise_error(ESM::Exception::CheckFailure)
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

      expect(previous_command.target_community).not_to be_nil
      expect(previous_command.target_community.id).to eq(community.id)
    end

    it "is invalid" do
      expect { execute!(arguments: {community_id: "es"}) }.to raise_error(ESM::Exception::CheckFailure) do |error|
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
      execute!(arguments: {target: secondary_user.discord_id})

      expect(previous_command.target_user).not_to be_nil
      expect(previous_command.target_user.discord_id).to eq(secondary_user.discord_id)
    end

    it "is invalid" do
      expect { execute!(arguments: {target: "000000000000000000"}) }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "creates" do
      discord_id = secondary_user.discord_id
      secondary_user.destroy

      execute!(arguments: {target: discord_id})

      new_target_user = ESM::User.find_by_discord_id(discord_id)
      expect(new_target_user).not_to be(nil)
      expect(previous_command.target_user.discord_id).to eq(new_target_user.discord_id)
    end
  end

  describe "#target_uid" do
    let!(:secondary_user) { ESM::Test.user }

    include_context "command" do
      let!(:command_class) { ESM::Command::Test::TargetCommand }
    end

    it "from Steam UID" do
      execute!(arguments: {target: secondary_user.steam_uid})
      expect(previous_command.target_uid).to eq(secondary_user.steam_uid)
    end

    it "from mention" do
      execute!(arguments: {target: secondary_user.mention})
      expect(previous_command.target_uid).to eq(secondary_user.steam_uid)
    end

    it "from discord ID" do
      execute!(arguments: {target: secondary_user.discord_id})
      expect(previous_command.target_uid).to eq(secondary_user.steam_uid)
    end

    it "from unregistered" do
      secondary_user.update(steam_uid: nil)

      execute!(arguments: {target: secondary_user.mention})
      expect(previous_command.target_uid).to eq(nil)
    end

    it "from gibberish" do
      expect { execute!(arguments: {target: "000000000000000000"}) }.to raise_error(ESM::Exception::CheckFailure)
      expect(previous_command.target_uid).to eq(nil)
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
      command.requirements.unset(:registration)
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

  describe "#from_discord!" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::ServerSuccessCommand }
    end

    it "is defined" do
      expect(command.respond_to?(:from_discord!)).to be(true)
    end

    it "executes" do
      expect {
        execute!(arguments: {server_id: server.server_id}, nullable: true)
      }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "executes with nullable arguments" do
      expect {
        execute!(arguments: {server_id: server.server_id})
      }.to raise_error(ESM::Exception::CheckFailure)
    end

    describe "Handles Errors", :error_testing do
      it "send error (CheckFailure)" do
        execution_args = {command_class: ESM::Command::Test::DirectMessageCommand}

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data

          expect(embed.description).to eq(
            "Hey #{user.mention}, this command can only be used in a **Direct Message** with me.\n\nJust right click my name, click **Message**, and send it there"
          )
        end
      end

      it "send error (StandardError)" do
        execute!(command_class: ESM::Command::Test::ErrorCommand, handle_error: true)
        wait_for { ESM::Test.messages.size }.to eq(1)

        error = ESM::Test.messages.first.content
        expect(error.description).to match(
          /an error occurred while processing your request.[[:space:]]Will you please join my \[Discord\]\(https...esmbot.com.join\) and post the following error code in the `#get-help-here` channel so my developer can fix it for you\?[[:space:]]Thank you![[:space:]]```\w+```/i
        )
      end

      it "resets cooldown when an error occurs", :requires_connection do
        execute!(command_class: ESM::Command::Test::ServerErrorCommand, arguments: {server_id: server.server_id})

        wait_for { ESM::Test.messages.size }.to eq(1)

        expect(previous_command.current_cooldown.active?).to be(false)
      end
    end
  end

  describe "#raise_error!" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::BaseV1 }
    end

    before do
      command.current_user = user
      command.current_channel = ESM::Test.channel
    end

    it "raises the translation" do
      expect {
        command.raise_error!(:text_only, user: user.mention, path_prefix: "command_errors")
      }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data

        expect(embed.description).to match(/this command can only be used in a discord server's \*\*text channel\*\*/i)
      end
    end

    it "raises the block" do
      expect { command.raise_error! { "This will is the message" } }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data).to match(/this will is the message/i)
      end
    end
  end

  describe "limit to" do
    context "when limit_to is unset" do
      include_context "command" do
        let!(:command_class) { ESM::Command::Test::PlayerCommand }
      end

      it "is not limited" do
        expect(command.limited_to).to be_nil

        expect(command.dm_only?).to be(false)
        expect(command.text_only?).to be(false)
      end

      it "executes in text channels" do
        execute!
      end

      it "executes in DM channels" do
        execute!(channel_type: :dm)
      end
    end

    context "when limit_to is set to Direct Message" do
      include_context "command" do
        let!(:command_class) { ESM::Command::Test::DirectMessageCommand }
      end

      it "supports multiple variations" do
        command_class.limit_to(:direct_message)
        expect(command_class.limited_to).to eq(:dm)

        command_class.limit_to(:dm)
        expect(command_class.limited_to).to eq(:dm)

        command_class.limit_to(:private_message)
        expect(command_class.limited_to).to eq(:dm)

        command_class.limit_to(:pm)
        expect(command_class.limited_to).to eq(:dm)
      end

      it "is limited to direct messages" do
        expect(command.limited_to).to eq(:dm)

        expect(command.dm_only?).to be(true)
        expect(command.text_only?).to be(false)
      end

      it "does not work in text channels" do
        expect { execute! }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match(/this command can only be used in a \*\*direct message\*\* with me/i)
        end
      end

      it "works in Direct Message channels" do
        execute!(channel_type: :dm)
      end
    end

    context "when limit_to is set to Text channel" do
      include_context "command" do
        let!(:command_class) { ESM::Command::Test::TextChannelCommand }
      end

      it "supports multiple variations" do
        command_class.limit_to(:text)
        expect(command_class.limited_to).to eq(:text)

        command_class.limit_to(:text_channel)
        expect(command_class.limited_to).to eq(:text)
      end

      it "is limited to text" do
        expect(command.limited_to).to eq(:text)
        expect(command.dm_only?).to be(false)
        expect(command.text_only?).to be(true)
      end

      it "works in text channels" do
        execute!
      end

      it "does not work in Direct Message channels" do
        expect { execute!(channel_type: :dm) }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match(
            /this command can only be used in a discord server's \*\*text channel\*\*\./i
          )
        end
      end
    end
  end

  describe "#create_or_update_cooldown" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CooldownCommand }
    end

    context "when there is no cooldown" do
      it "creates one" do
        expect(ESM::Cooldown.all.size).to eq(0)
        execute!

        expect(previous_command.current_cooldown).to be_kind_of(ESM::Cooldown)
        expect(previous_command.current_cooldown.valid?).to be(true)
        expect(previous_command.current_cooldown.persisted?).to be(true)
      end
    end

    context "when there is a cooldown" do
      it "updates it" do
        cooldown = create(
          :cooldown, :inactive,
          steam_uid: user.steam_uid,
          community_id: community.id,
          command_name: command.command_name
        )

        execute!

        expect(previous_command.current_cooldown).to be_kind_of(ESM::Cooldown)
        expect(previous_command.current_cooldown.valid?).to be(true)
        expect(previous_command.current_cooldown.persisted?).to be(true)
        expect(previous_command.current_cooldown.id).to eq(cooldown.id)
      end
    end
  end

  describe "#current_cooldown_query" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CooldownCommand }
    end

    let(:query_hash) { command.current_cooldown_query.where_values_hash.symbolize_keys }
    let!(:target_community) { ESM::Test.second_community }

    before do
      command.requirements.unset(:registration)
      command.instance_variable_set(:@current_user, user)
    end

    context "when registration is not required" do
      it "uses the user id" do
        expect(query_hash).to include(
          command_name: command.command_name, user_id: user.id
        ).and exclude(
          :steam_uid, :server_id, :community_id
        )
      end
    end

    context "when registration is required" do
      before do
        command.requirements.set(:registration)
      end

      it "uses the steam uid" do
        expect(query_hash).to include(
          command_name: command.command_name, steam_uid: user.steam_uid
        ).and exclude(
          :user_id, :server_id, :community_id
        )
      end
    end

    context "when there is a target community" do
      before do
        command.instance_variable_set(:@current_community, community)
        command.instance_variable_set(:@target_community, target_community)
      end

      it "uses the target community's ID" do
        expect(query_hash).to include(
          command_name: command.command_name, user_id: user.id, community_id: target_community.id
        ).and exclude(
          :steam_uid, :server_id
        )
      end
    end

    context "when there is a current community, but no target community" do
      before do
        command.instance_variable_set(:@current_community, community)
      end

      it "uses the current community's ID" do
        expect(query_hash).to include(
          command_name: command.command_name, user_id: user.id, community_id: community.id
        ).and exclude(
          :steam_uid, :server_id
        )
      end
    end

    context "when there is a target server" do
      before do
        command.instance_variable_set(:@target_server, server)
      end

      it "uses the target server's ID" do
        expect(query_hash).to include(
          command_name: command.command_name, user_id: user.id, server_id: server.id
        ).and exclude(
          :steam_uid
        )
      end
    end
  end

  describe "#on_cooldown?" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CooldownCommand }
    end

    it "respond" do
      expect(command.respond_to?(:on_cooldown?)).to be(true)
    end

    context "when the command is on cooldown" do
      it "raises an exception" do
        cooldown = create(
          :cooldown, :active, user: user, community: community,
          command_name: command.command_name
        )

        command.instance_variable_set(:@current_cooldown, cooldown)

        expect(command.current_cooldown).to eq(cooldown)
        expect(command.on_cooldown?).to be(true)
      end
    end

    context "when the command is not on cooldown" do
      it "does not raise an exception" do
        cooldown = create(
          :cooldown, :inactive, user: user, community: community,
          command_name: command.command_name
        )

        command.instance_variable_set(:@current_cooldown, cooldown)

        expect(command.current_cooldown).to eq(cooldown)
        expect(command.on_cooldown?).to be(false)
      end
    end
  end

  # Truth table: https://docs.google.com/spreadsheets/d/1BDHVwhyvgbFPlXnAtFKzOcPtGhZ1zG5H-_1km3VXKr8/edit#gid=0
  describe "Command Permissions" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::CommunityCommand }
    end

    let(:configuration) { ESM::CommandConfiguration.where(command_name: command.command_name).first }
    let(:allowlisted_role_ids) { community.role_ids }

    describe "Text Channel" do
      describe "Allowed" do
        it "enabled: true, allowlist_enabled: false, allowlisted: false, allowed: true" do
          configuration.update!(
            enabled: true,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: true
          )

          execute!(arguments: {community_id: community.community_id})
        end

        it "enabled: true, allowlist_enabled: true, allowlisted: true, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: true
          )

          # CHECK THAT user ACTUALLY HAS ROLE
          execute!(user: role_user, arguments: {community_id: community.community_id})
        end
      end

      describe "Denied" do
        it "enabled: false, allowlist_enabled: false, allowlisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, notify_when_disabled: true" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: true
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, notify_when_disabled: false" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: false
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailureNoMessage)

          # It did not send a message
          expect(ESM::Test.messages.size).to eq(0)
        end

        it "enabled: false, allowlist_enabled: false, allowlisted: false, allowed: true" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: true, allowlisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: true,
            allowlisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: true, allowlisted: true, allowed: false" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: false
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: true, allowlisted: true, allowed: true" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: true
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: true, allowlist_enabled: false, allowlisted: false, allowed: false" do
          configuration.update!(
            enabled: true,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not allowed/i)
        end

        it "enabled: true, allowlist_enabled: true, allowlisted: false, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            allowlist_enabled: true,
            allowlisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(user: role_user, arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end

        it "enabled: true, allowlist_enabled: true, allowlisted: true, allowed: false" do
          configuration.update!(
            enabled: true,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: false
          )

          expect {
            execute!(arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not have permission/i)
        end
      end
    end

    describe "Private Message" do
      describe "Allowed" do
        it "enabled: true, allowlist_enabled: false, allowlisted: false, allowed: true" do
          configuration.update!(
            enabled: true,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: true
          )

          execute!(channel_type: :pm, arguments: {community_id: community.community_id})
        end

        it "enabled: true, allowlist_enabled: true, allowlisted: true, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: true
          )

          execute!(channel_type: :pm, user: role_user, arguments: {community_id: community.community_id})
        end

        it "enabled: true, allowlist_enabled: false, allowlisted: false, allowed: false" do
          configuration.update!(
            enabled: true,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: false
          )

          execute!(channel_type: :pm, arguments: {community_id: community.community_id})
        end

        it "enabled: true, allowlist_enabled: true, allowlisted: true, allowed: false" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: false
          )

          execute!(channel_type: :pm, user: role_user, arguments: {community_id: community.community_id})
        end
      end

      describe "Denied" do
        it "enabled: false, notify_when_disabled: true" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: true
          )

          expect {
            execute!(channel_type: :pm, arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, notify_when_disabled: false" do
          configuration.update!(
            enabled: false,
            notify_when_disabled: false
          )

          expect {
            execute!(channel_type: :pm, arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: false, allowlisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(channel_type: :pm, arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: false, allowlisted: false, allowed: true" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: false,
            allowlisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(channel_type: :pm, arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: true, allowlisted: false, allowed: false" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: true,
            allowlisted_role_ids: [],
            allowed_in_text_channels: false
          )

          expect {
            execute!(
              channel_type: :pm,
              user: user,
              arguments: {
                community_id: community.community_id
              }
            )
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: true, allowlisted: true, allowed: false" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: true,
            allowlisted_role_ids: community.role_ids,
            allowed_in_text_channels: false
          )

          expect {
            execute!(
              channel_type: :pm,
              user: user,
              arguments: {
                community_id: community.community_id
              }
            )
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: false, allowlist_enabled: true, allowlisted: true, allowed: true" do
          configuration.update!(
            enabled: false,
            allowlist_enabled: true,
            allowlisted_role_ids: allowlisted_role_ids,
            allowed_in_text_channels: true
          )

          expect {
            execute!(channel_type: :pm, arguments: {community_id: community.community_id})
          }.to raise_error(ESM::Exception::CheckFailure, /not enabled/i)
        end

        it "enabled: true, allowlist_enabled: true, allowlisted: false, allowed: true" do
          role_user = ESM::Test.user(:with_role)
          configuration.update!(
            enabled: true,
            allowlist_enabled: true,
            allowlisted_role_ids: [],
            allowed_in_text_channels: true
          )

          expect {
            execute!(channel_type: :pm, user: role_user, arguments: {community_id: community.community_id})
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

    it "ensures server community and player community are not the same" do
      expect(player_community.id).not_to eq(server_community.id)
    end

    it "is enabled" do
      expect(player_community.player_mode_enabled?).to be(true)
    end

    it "is able to use DM only commands in text channel" do
      execute!(command_class: ESM::Command::Test::DirectMessageCommand)
    end

    it "is able to run player command for other communities in text channel" do
      # Ensure the command can still be used regardless of that communities permissions for "allowed_in_text_channels"
      player_community.command_configurations
        .where(command_name: command.command_name)
        .first
        .update!(allowed_in_text_channels: false)

      execute!(community_id: server_community.community_id)
    end

    it "does not allow admin commands in text channel" do
      expect {
        execute!(
          command_class: ESM::Command::Test::AdminCommand,
          arguments: {
            community_id: server_community.community_id
          }
        )
      }.to raise_error(ESM::Exception::CheckFailure, /is not available in player mode/i)
    end

    it "does not allow running commands for other communities in another server community's text channels" do
      expect {
        execute!(
          channel: ESM::Test.channel(in: server_community),
          arguments: {
            community_id: player_community.community_id
          }
        )
      }.to raise_error(ESM::Exception::CheckFailure, /commands for other communities/i)
    end
  end

  describe "#skip_action" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::SkipServerCheckCommand }
    end

    it "skips #check_for_connected_server!" do
      execute!(arguments: {server_id: server.server_id})
    end
  end

  describe "#skip" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::SkipCooldownCommand }
    end

    it "skips #create_or_update_cooldown" do
      execute!(arguments: {server_id: server.server_id})

      expect(previous_command.current_cooldown).to eq(nil)
    end
  end

  describe "#add_request" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::RequestCommand }
    end

    it "adds the request" do
      execute!(arguments: {target: second_user.discord_id})

      expect(ESM::Request.all.size).to eq(1)
      expect(second_user.pending_requests.size).to eq(1)
    end
  end

  describe "#from_request" do
    include_context "command" do
      let!(:command_class) { ESM::Command::Test::RequestCommand }
    end

    it "is accepted" do
      execute!(arguments: {target: second_user.discord_id})

      request = ESM::Request.first
      request.respond(true)

      wait_for { ESM::Test.messages.size }.to eq(2)

      expect(ESM::Test.messages.first.second).to be_a(ESM::Embed)
      expect(ESM::Test.messages.second.second).to eq("accepted")
    end

    it "is declined" do
      execute!(arguments: {target: second_user.discord_id})

      request = ESM::Request.first
      request.respond(false)

      wait_for { ESM::Test.messages.size }.to eq(2)

      expect(ESM::Test.messages.first.second).to be_a(ESM::Embed)
      expect(ESM::Test.messages.second.second).to eq("declined")
    end
  end
end
