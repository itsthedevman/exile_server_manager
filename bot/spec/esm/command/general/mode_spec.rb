# frozen_string_literal: true

describe ESM::Command::General::Mode, category: "command" do
  let!(:command) { ESM::Command::General::Mode.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 2 arguments" do
    expect(command.arguments.size).to eql(2)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    # This requires an owner user
    let!(:community) { ESM::Test.community }
    let!(:owner) { create(:esm_dev) }

    it "should disable player mode and return an embed" do
      response = nil
      community.update(player_mode_enabled: true)

      event = CommandEvent.create("!mode #{community.community_id} server", user: owner, channel_type: :dm)
      expect { response = command.execute(event) }.not_to raise_error
      expect(response).not_to be_nil
      community.reload

      expect(community.player_mode_enabled?).to be(false)

      expect(response.description).to eql(I18n.t("commands.mode.disabled", community_name: community.name))
      expect(response.color).to eql(ESM::Color::Toast::GREEN)
    end

    it "should enable player mode and return an embed" do
      response = nil
      community.update(player_mode_enabled: false)

      event = CommandEvent.create("!mode #{community.community_id} player", user: owner, channel_type: :dm)
      expect { response = command.execute(event) }.not_to raise_error
      expect(response).not_to be_nil
      community.reload

      expect(community.player_mode_enabled?).to be(true)

      expect(response.description).to eql(I18n.t("commands.mode.enabled", community_name: community.name))
      expect(response.color).to eql(ESM::Color::Toast::GREEN)
    end

    it "should raise same_mode error (server)" do
      community.update(player_mode_enabled: false)
      event = CommandEvent.create("!mode #{community.community_id} server", user: owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.title).to eql("Looks like there's nothing to change")
        expect(embed.description).to eql("You already have player mode disabled 👍")
        expect(embed.color).to eql(ESM::Color::Toast::YELLOW)
      end
    end

    it "should raise same_mode error (player)" do
      community.update(player_mode_enabled: true)
      event = CommandEvent.create("!mode #{community.community_id} player", user: owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.title).to eql(I18n.t("commands.mode.error_messages.same_mode.title"))
        expect(embed.description).to eql(I18n.t("commands.mode.error_messages.same_mode.description", state: "enabled"))
        expect(embed.color).to eql(ESM::Color::Toast::YELLOW)
      end
    end

    it "should raise servers error" do
      # We need to create a server
      ESM::Test.server
      community.update(player_mode_enabled: false)
      event = CommandEvent.create("!mode #{community.community_id} player", user: owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.title).to eql(I18n.t("commands.mode.error_messages.servers_exist.title", user: event.user.mention))
        expect(embed.description).to eql("In order to enable player mode, you must remove any servers you have added to me via my [Dashboard](https://www.esmbot.com/portal)")
        expect(embed.color).to eql(ESM::Color::Toast::RED)
      end
    end

    it "should not be allowed" do
      non_owner = ESM::Test.user
      event = CommandEvent.create("!mode #{community.community_id} player", user: non_owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.title).to eql(I18n.t("commands.mode.error_messages.no_permissions.title", user: event.user.mention))
        expect(embed.description).to eql(I18n.t("commands.mode.error_messages.no_permissions.description", user: event.user.mention))
        expect(embed.color).to eql(ESM::Color::Toast::RED)
      end
    end
  end
end
