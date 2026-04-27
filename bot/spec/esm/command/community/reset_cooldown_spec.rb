# frozen_string_literal: true

describe ESM::Command::Community::ResetCooldown, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    let(:second_community) { ESM::Test.second_community }
    let(:second_server) { ESM::Test.server(for: second_community) }
    let!(:target_regex) { ESM::Regex::TARGET.source }

    let!(:cooldown_one) do
      create(
        :cooldown,
        user_id: second_user.id,
        community_id: community.id,
        server_id: server.id,
        command_name: "me",
        expires_at: Time.zone.now + 5.minutes,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    let!(:cooldown_two) do
      create(
        :cooldown,
        user_id: second_user.id,
        community_id: community.id,
        server_id: second_server.id,
        command_name: "me",
        expires_at: Time.zone.now + 5.minutes,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    before do
      # Grant everyone access to use this command
      grant_command_access!(community, "reset_cooldown")

      # Force the configuration to be correct
      community.command_configurations
        .where(command_name: "me")
        .update(cooldown_type: "minutes", cooldown_quantity: 5)

      expect(cooldown_one.active?).to be(true)
      expect(cooldown_two.active?).to be(true)
    end

    context "when the target is provided" do
      it "resets the target's cooldowns for this community" do
        execute!(arguments: {target: second_user.mention}, prompt_response: "yes")
        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for your community/i)

        # Check confirmation embed
        confirmation_embed = ESM::Test.messages.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for all commands\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Check cooldowns
        expect(cooldown_one.reload.active?).to be(false)
        expect(cooldown_two.reload.active?).to be(false)
      end
    end

    context "when the target and command name are provided" do
      it "resets the target's cooldowns for the provided command in this community" do
        execute!(arguments: {target: second_user.mention, command: "me"}, prompt_response: "yes")
        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for `me` on every server your community has registered with me\./i)

        # Check confirmation embed
        confirmation_embed = ESM::Test.messages.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for `me`\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Check cooldowns
        expect(cooldown_one.reload.active?).to be(false)
        expect(cooldown_two.reload.active?).to be(false)
      end
    end

    context "when the target, command name, and server id are provided" do
      it "resets the target's cooldowns for the provided command, but only for the provided server" do
        execute!(
          arguments: {target: second_user.mention, command: "me", server_id: server.server_id},
          prompt_response: "yes"
        )

        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for `me` . this change will only be applied to `#{server.server_id}`/i)

        # Check confirmation embed
        confirmation_embed = ESM::Test.messages.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for `me`. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Check cooldowns
        expect(cooldown_one.reload.active?).to be(false)
        expect(cooldown_two.reload.active?).to be(true)
      end
    end

    context "when the target and server id are provided" do
      it "resets the target's cooldowns for all commands, but only for the provided server" do
        execute!(arguments: {target: second_user.mention, server_id: server.server_id}, prompt_response: "yes")
        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for all commands on `#{server.server_id}`/i)

        # Check confirmation embed
        confirmation_embed = ESM::Test.messages.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for all commands\. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Check cooldowns
        expect(cooldown_one.reload.active?).to be(false)
        expect(cooldown_two.reload.active?).to be(true)
      end
    end

    context "when the command name is provided" do
      it "resets all cooldowns for the provided command for every server in this community" do
        execute!(arguments: {command: "me"}, prompt_response: "yes")
        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for `me` on every server your community has registered with me.`/i)

        # Check confirmation embed
        confirmation_embed = ESM::Test.messages.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for `me`\. this change will be applied to every server your community has registered with me\./i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Check cooldowns
        expect(cooldown_one.reload.active?).to be(false)
        expect(cooldown_two.reload.active?).to be(false)
      end
    end

    context "when the command and server id are provided" do
      it "resets all cooldowns for the provided command for all servers in this community" do
        execute!(arguments: {command: "me", server_id: server.server_id}, prompt_response: "yes")
        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.first.content
        expect(response).not_to be(nil)
        expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for `me` on `#{server.server_id}`/i)

        # Check confirmation embed
        confirmation_embed = ESM::Test.messages.first.content

        expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for `me`\. this change will only be applied to `#{server.server_id}`/i)
        expect(confirmation_embed.fields.size).to eq(1)

        # Check cooldowns
        expect(cooldown_one.reload.active?).to be(false)
        expect(cooldown_two.reload.active?).to be(true)
      end
    end

    context "when the command is invalid" do
      it "raises an exception" do
        execution_args = {arguments: {target: second_user.mention, command: "NOOP"}}

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
      end
    end

    context "when the reset is cancelled by replying no" do
      it "declines the reset and does nothing" do
        execute!(
          arguments: {target: second_user.mention, command: "me", server_id: server.server_id},
          prompt_response: "no"
        )

        wait_for { ESM::Test.messages.size }.to eq(2)

        # Check success message
        response = ESM::Test.messages.second.second
        expect(response).not_to be(nil)
        expect(response).to match(/i've cancelled your request/i)
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
end
