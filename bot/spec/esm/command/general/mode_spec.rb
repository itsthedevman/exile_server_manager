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
      community.update(player_mode_enabled: true)

      command_statement = command.statement(community_id: community.community_id, mode: "server")
      event = CommandEvent.create(command_statement, user: owner, channel_type: :dm)
      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      community.reload

      expect(community.player_mode_enabled?).to be(false)

      expect(response.description).to eql(I18n.t("commands.mode.disabled", community_name: community.name))
      expect(response.color).to eql(ESM::Color::Toast::GREEN)
    end

    it "should enable player mode and return an embed" do
      community.update(player_mode_enabled: false)

      command_statement = command.statement(community_id: community.community_id, mode: "player")
      event = CommandEvent.create(command_statement, user: owner, channel_type: :dm)
      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      community.reload

      expect(community.player_mode_enabled?).to be(true)

      expect(response.description).to eql(I18n.t("commands.mode.enabled", community_name: community.name))
      expect(response.color).to eql(ESM::Color::Toast::GREEN)
    end

    it "should raise same_mode error (server)" do
      community.update(player_mode_enabled: false)
      command_statement = command.statement(community_id: community.community_id, mode: "server")
      event = CommandEvent.create(command_statement, user: owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.description).to match(/like there's nothing to change! you already have player mode disabled/i)
      end
    end

    it "should raise same_mode error (player)" do
      community.update(player_mode_enabled: true)
      command_statement = command.statement(community_id: community.community_id, mode: "player")
      event = CommandEvent.create(command_statement, user: owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.description).to match(/like there's nothing to change! you already have player mode enabled/i)
      end
    end

    it "should raise servers error" do
      # We need to create a server
      ESM::Test.server
      community.update(player_mode_enabled: false)
      command_statement = command.statement(community_id: community.community_id, mode: "player")
      event = CommandEvent.create(command_statement, user: owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.description).to match(/in order to enable player mode, you must remove any servers you have added to me via my/i)
      end
    end

    it "should not be allowed" do
      non_owner = ESM::Test.user
      command_statement = command.statement(community_id: community.community_id, mode: "player")
      event = CommandEvent.create(command_statement, user: non_owner, channel_type: :dm)

      expect { command.execute(event) }.to raise_error do |error|
        embed = error.data
        expect(embed.description).to match(/only the owner of this community has access to this command/i)
      end
    end
  end
end
