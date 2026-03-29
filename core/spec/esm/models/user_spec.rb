# frozen_string_literal: true

RSpec.describe ESM::User do
  describe ".find_by_discord_id" do
    let!(:user) { create(:user) }

    it "finds user by discord_id string" do
      result = described_class.find_by_discord_id(user.discord_id)
      expect(result).to eq(user)
    end

    it "handles parsing an integer" do
      result = described_class.find_by_discord_id(user.discord_id.to_i)
      expect(result).to eq(user)
    end

    it "returns nil when not found" do
      expect(described_class.find_by_discord_id("000000000000000000")).to be_nil
    end
  end

  describe ".find_by_steam_uid" do
    let!(:user) { create(:user) }

    it "finds user by steam_uid" do
      result = described_class.find_by_steam_uid(user.steam_uid)
      expect(result).to eq(user)
    end

    it "returns nil when not found" do
      expect(described_class.find_by_steam_uid("76560000000000000")).to be_nil
    end
  end

  describe "#registered?" do
    it "returns true when user has steam_uid" do
      user = create(:user)
      expect(user.registered?).to be(true)
    end

    it "returns false when user has no steam_uid" do
      user = create(:user, :unregistered)
      expect(user.registered?).to be(false)
    end
  end

  describe "#mention" do
    let!(:user) { create(:user) }

    it "returns Discord mention format" do
      expect(user.mention).to eq("<@#{user.discord_id}>")
    end

    it "is aliased as discord_mention" do
      expect(user.discord_mention).to eq(user.mention)
    end
  end

  describe "#public_id" do
    let!(:user) { create(:user) }

    it "returns the discord_id" do
      expect(user.public_id).to eq(user.discord_id)
    end
  end
end
