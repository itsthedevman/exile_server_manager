# frozen_string_literal: true

describe ESM::Command::Community::ResetCooldown, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    let!(:target_regex) { ESM::Regex::TARGET.source }

    let(:second_community) { create(:community) }
    let(:second_server) { create(:server, community_id: second_community.id) }
    let(:other_server) { create(:server, community_id: community.id) }
    let(:bystander) { create(:user, :with_discord_member, discord_server: discord_server) }

    # A cooldown row carries only one of user_id or steam_uid. Cooldown.scope_for keys on steam_uid for a
    # registration-gated command and on user_id for everything else, and the first_or_create behind it leaves the
    # other column nil. Both shapes belong to the same player, so a reset aimed at that player has to clear both.
    let!(:target_cooldown) { active_cooldown(steam_uid: second_user.steam_uid, server:) }
    let!(:target_cooldown_by_user_id) { active_cooldown(user_id: second_user.id, server:, command_name: "id") }

    let!(:target_cooldown_on_other_server) do
      active_cooldown(steam_uid: second_user.steam_uid, server: other_server)
    end

    let!(:target_cooldown_for_other_command) do
      active_cooldown(steam_uid: second_user.steam_uid, server:, command_name: "gamble")
    end

    # scope_for only pins a server when the command targets one, so every community-scoped command leaves its
    # cooldown with a null server_id. A server-scoped reset has to skip these; a community-wide one has to catch them.
    let!(:target_cooldown_without_a_server) do
      active_cooldown(steam_uid: second_user.steam_uid, server: nil, command_name: "reset_cooldown")
    end

    let!(:target_reward_cooldown) do
      exhausted_cooldown(steam_uid: second_user.steam_uid, server:, command_name: "reward")
    end

    let!(:bystander_cooldown) { active_cooldown(steam_uid: bystander.steam_uid, server:) }

    let!(:foreign_cooldown) do
      active_cooldown(steam_uid: second_user.steam_uid, server: second_server, community: second_community)
    end

    let(:all_cooldowns) do
      {
        target_cooldown:,
        target_cooldown_by_user_id:,
        target_cooldown_on_other_server:,
        target_cooldown_for_other_command:,
        target_cooldown_without_a_server:,
        target_reward_cooldown:,
        bystander_cooldown:,
        foreign_cooldown:
      }
    end

    before do
      # Grant everyone access to use this command
      grant_command_access!(community, "reset_cooldown")

      # A configuration change reconciles the community's existing rows to match it, so the fixtures have to agree
      # with their configuration or they get rewritten out from under the scenario.
      community.command_configurations
        .where(command_name: %w[me gamble id reset_cooldown])
        .update(cooldown_type: "minutes", cooldown_quantity: 5)

      community.command_configurations
        .where(command_name: "reward")
        .update(cooldown_type: "times", cooldown_quantity: 1)

      expect(all_cooldowns.values).to all(be_active)
    end

    #
    # A time-based cooldown long enough to still be running when the command executes. Callers vary only who owns it
    # and where it lives, since that is the whole of what the command's scoping decides.
    #
    # @param server [ESM::Server, nil] the server the cooldown belongs to, or nil for a community-scoped command
    # @param community [ESM::Community] the community the cooldown belongs to
    # @param command_name [String] the command the cooldown governs
    # @param owner [Hash] either steam_uid: or user_id:, matching how the real row would have been keyed
    #
    # @return [ESM::Cooldown]
    #
    def active_cooldown(server:, community: self.community, command_name: "me", **owner)
      create(
        :cooldown,
        community_id: community.id,
        server_id: server&.id,
        command_name:,
        expires_at: 5.minutes.from_now,
        cooldown_type: "minutes",
        cooldown_quantity: 5,
        **owner
      )
    end

    #
    # A usage-count cooldown with its allowance spent, the shape communities put on `/server reward` and the reason
    # this command gets run at all. `active?` weighs cooldown_amount against cooldown_quantity here rather than
    # reading expires_at, and `reset!` is what puts the count back to zero, so a reward reset travels its own branch.
    #
    # @param server [ESM::Server, nil] the server the cooldown belongs to
    # @param command_name [String] the command the cooldown governs
    # @param owner [Hash] either steam_uid: or user_id:, matching how the real row would have been keyed
    #
    # @return [ESM::Cooldown]
    #
    def exhausted_cooldown(server:, command_name:, **owner)
      create(
        :cooldown,
        community_id: community.id,
        server_id: server&.id,
        command_name:,
        cooldown_type: "times",
        cooldown_quantity: 1,
        cooldown_amount: 1,
        **owner
      )
    end

    #
    # Assert exactly which rows the run cleared. Every row not named is required to have survived, so a scope that
    # reaches further than it claims fails here instead of passing on the rows it was supposed to leave alone.
    #
    # @param names [Array<Symbol>] the let names of the cooldowns expected to have been reset
    #
    # @return [void]
    #
    def expect_only_reset(*names)
      all_cooldowns.each do |name, cooldown|
        if names.include?(name)
          expect(cooldown.reload.active?).to be(false), "expected #{name} to have been reset"
        else
          expect(cooldown.reload.active?).to be(true), "expected #{name} to have survived"
        end
      end
    end

    context "when no arguments are provided" do
      it "resets every cooldown in this community and nothing outside it" do
        execute!(arguments: {}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for all commands on every server your community has registered with me\./i)

        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for all commands\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        expect_only_reset(
          :target_cooldown,
          :target_cooldown_by_user_id,
          :target_cooldown_on_other_server,
          :target_cooldown_for_other_command,
          :target_cooldown_without_a_server,
          :target_reward_cooldown,
          :bystander_cooldown
        )
      end
    end

    context "when the target is provided" do
      it "resets the target's cooldowns for this community" do
        execute!(arguments: {target: second_user.mention}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for your community/i)

        # Check confirmation embed
        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for all commands\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Both key shapes belong to the target, so both go; the bystander and the other community do not.
        expect_only_reset(
          :target_cooldown,
          :target_cooldown_by_user_id,
          :target_cooldown_on_other_server,
          :target_cooldown_for_other_command,
          :target_cooldown_without_a_server,
          :target_reward_cooldown
        )
      end
    end

    context "when the target is provided as a registered steam uid" do
      it "resolves the uid to the same player a mention would have" do
        execute!(arguments: {target: second_user.steam_uid}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        expect_only_reset(
          :target_cooldown,
          :target_cooldown_by_user_id,
          :target_cooldown_on_other_server,
          :target_cooldown_for_other_command,
          :target_cooldown_without_a_server,
          :target_reward_cooldown
        )
      end
    end

    context "when the target and command name are provided" do
      it "resets the target's cooldowns for the provided command in this community" do
        execute!(arguments: {target: second_user.mention, command: "me"}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for `me` on every server your community has registered with me\./i)

        # Check confirmation embed
        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for `me`\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        expect_only_reset(:target_cooldown, :target_cooldown_on_other_server)
      end
    end

    context "when the target and a usage-count command are provided" do
      it "clears the spent allowance rather than an expiry" do
        execute!(arguments: {target: second_user.mention, command: "reward"}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        expect(target_reward_cooldown.reload.cooldown_amount).to eq(0)
        expect_only_reset(:target_reward_cooldown)
      end
    end

    context "when the target, command name, and server id are provided" do
      it "resets the target's cooldowns for the provided command, but only for the provided server" do
        execute!(
          arguments: {target: second_user.mention, command: "me", server_id: server.server_id},
          prompt_response: "yes"
        )

        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for `me` . this change will only be applied to `#{server.server_id}`/i)

        # Check confirmation embed
        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for `me`. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        expect_only_reset(:target_cooldown)
      end
    end

    context "when the target and server id are provided" do
      it "resets the target's cooldowns for all commands, but only for the provided server" do
        execute!(arguments: {target: second_user.mention, server_id: server.server_id}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for all commands on `#{server.server_id}`/i)

        # Check confirmation embed
        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for all commands\. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        # The serverless row is the target's too, but naming a server is what excludes it.
        expect_only_reset(
          :target_cooldown,
          :target_cooldown_by_user_id,
          :target_cooldown_for_other_command,
          :target_reward_cooldown
        )
      end
    end

    context "when only the server id is provided" do
      it "resets everyone's cooldowns on that server alone" do
        execute!(arguments: {server_id: server.server_id}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for all commands on `#{server.server_id}`/i)

        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for all commands\. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        expect_only_reset(
          :target_cooldown,
          :target_cooldown_by_user_id,
          :target_cooldown_for_other_command,
          :target_reward_cooldown,
          :bystander_cooldown
        )
      end
    end

    context "when the command name is provided" do
      it "resets all cooldowns for the provided command for every server in this community" do
        execute!(arguments: {command: "me"}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for `me` on every server your community has registered with me.`/i)

        # Check confirmation embed
        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for `me`\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        expect_only_reset(:target_cooldown, :target_cooldown_on_other_server, :bystander_cooldown)
      end
    end

    context "when the command and server id are provided" do
      it "resets all cooldowns for the provided command for all servers in this community" do
        execute!(arguments: {command: "me", server_id: server.server_id}, prompt_response: "yes")
        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for `me` on `#{server.server_id}`/i)

        # Check confirmation embed
        confirmation_embed = ESM.discord_bot.test_outbox.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for `me`\. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        expect_only_reset(:target_cooldown, :bystander_cooldown)
      end
    end

    context "when the server id belongs to a community the caller also administers" do
      # Access is granted in both so the refusal cannot be credited to the allowlist. What stops it is that a text
      # channel only ever acts on its own community, which lands well before on_execute: check_for_owned_server! is
      # the same rule stated again inside the command, and for a text-only command it is never the one that fires.
      before { grant_command_access!(second_community, "reset_cooldown") }

      it "refuses before anything is reset" do
        execution_args = {arguments: {server_id: second_server.server_id}}

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
          expect(error.to_embed.description).to match(/using commands for other communities is only allowed/i)
        end

        expect_only_reset
      end
    end

    context "when the command is invalid" do
      it "raises an exception" do
        execution_args = {arguments: {target: second_user.mention, command: "NOOP"}}

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::InvalidArguments)
      end
    end

    context "when the reset is cancelled by replying no" do
      it "declines the reset and does nothing" do
        execute!(
          arguments: {target: second_user.mention, command: "me", server_id: server.server_id},
          prompt_response: "no"
        )

        ESM.discord_bot.test_outbox.await_size(2)

        # Check success message
        response = ESM.discord_bot.test_outbox.second.content
        expect(response).not_to be(nil)
        expect(response).to match(/i've cancelled your request/i)

        expect_only_reset
      end
    end

    context "when the target is an unregistered steam uid" do
      it "raises an exception" do
        steam_uid = second_user.steam_uid
        second_user.update(steam_uid: "")

        execution_args = {
          arguments: {target: steam_uid, command: "me"}
        }

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure, /not registered/i)
      end
    end
  end

  describe "#on_website_execute" do
    let!(:cooldown) do
      create(
        :cooldown,
        community_id: community.id,
        server_id: server.id,
        command_name: "me",
        steam_uid: second_user.steam_uid,
        expires_at: 5.minutes.from_now,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    before { grant_command_access!(community, "reset_cooldown") }

    it "clears the scope and answers with how many it cleared" do
      service_command = execute_website!(arguments: {target: second_user.mention, command: "me"})

      expect(service_command).to be_completed
      expect(service_command.result[:cleared]).to eq(1)
      expect(cooldown.reload.active?).to be(false)
    end

    # Discord never reaches check_for_owned_server!, because a text channel is refused a foreign community during the
    # lifecycle and long before on_execute. from_website! runs no equivalent, so over HTTP this check is the whole of
    # the boundary between two communities rather than a restatement of one already enforced.
    it "refuses a server belonging to another community" do
      second_community = create(:community)
      second_server = create(:server, community_id: second_community.id)

      # Granted there too, so the refusal cannot be credited to the allowlist. Permissions resolve against the named
      # server's community, and an admin of both would otherwise sail through to the reset.
      grant_command_access!(second_community, "reset_cooldown")

      service_command = execute_website!(arguments: {server_id: second_server.server_id})

      expect(service_command).to be_failed
      expect(service_command.error_message).to match(/you can only access servers belonging to/i)
      expect(cooldown.reload.active?).to be(true)
    end
  end
end
