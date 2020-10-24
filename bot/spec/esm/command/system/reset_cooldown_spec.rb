# frozen_string_literal: true

describe ESM::Command::System::ResetCooldown, category: "command" do
  let!(:command) { ESM::Command::System::ResetCooldown.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 3 argument" do
    expect(command.arguments.size).to eql(3)
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
    let(:second_community) { ESM::Test.second_community }
    let(:second_server) { ESM::Test.second_server }
    let(:second_user) { ESM::Test.second_user }
    let!(:target_regex) { ESM::Regex::TARGET.source }

    let(:cooldown_one) do
      ESM::Cooldown.create!(
        user_id: second_user.id,
        community_id: community.id,
        server_id: server.id,
        command_name: "me",
        expires_at: Time.now + 5.minutes,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    let(:cooldown_two) do
      ESM::Cooldown.create!(
        user_id: second_user.id,
        community_id: community.id,
        server_id: second_server.id,
        command_name: "me",
        expires_at: Time.now + 5.minutes,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    before :each do
      # Grant everyone access to use this command
      configuration = community.command_configurations.where(command_name: "reset_cooldown").first
      configuration.update(whitelist_enabled: false)

      # Force the configuration to be correct
      community.command_configurations.where(command_name: "me").update(cooldown_type: "minutes", cooldown_quantity: 5)

      expect(cooldown_one.reload.active?).to be(true)
      expect(cooldown_two.reload.active?).to be(true)
    end

    it "!reset_cooldown <target>" do
      command_statement = command.statement(target: second_user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for your community/i)

      # Check confirmation embed
      expect(ESM::Test.messages.size).to eql(2)
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for your community/i)
      expect(confirmation_embed.fields.size).to eql(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(false)
    end

    it "!reset_cooldown <target> <command_name>" do
      command_statement = command.statement(target: second_user.mention, command_name: "me")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s `me` cooldown for your community (including servers)/i)

      # Check confirmation embed
      expect(ESM::Test.messages.size).to eql(2)
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s `me` cooldown for your community (including servers)/i)
      expect(confirmation_embed.fields.size).to eql(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(false)
    end

    it "!reset_cooldown <target> <command_name> <server_id>" do
      command_statement = command.statement(target: second_user.mention, command_name: "me", server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s `me` cooldown for `#{server.server_id}`/i)

      # Check confirmation embed
      expect(ESM::Test.messages.size).to eql(2)
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s `me` cooldown for `#{server.server_id}`/i)
      expect(confirmation_embed.fields.size).to eql(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(true)
    end

    # This should not be possible
    it "!reset_cooldown <target> <server_id>" do
      command_statement = command.statement(target: second_user.mention, server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not one of my commands/i)
    end

    it "should raise error (Invalid Command)" do
      command_statement = command.statement(target: second_user.mention, command_name: "NOUP")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not one of my commands/i)
    end

    it "should decline" do
      command_statement = command.statement(target: second_user.mention, command_name: "me", server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "no"
      expect { command.execute(event) }.not_to raise_error

      # Check success message
      response = ESM::Test.messages.second.second
      expect(response).not_to be(nil)
      expect(response).to match(/i've cancelled your request/i)
    end

    it "should not allow an un-registered steam uid" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(target: steam_uid, command_name: "me")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not registered/i)
    end
  end
end
