# frozen_string_literal: true

describe ESM::User do
  describe "#discord_user" do
    it "should return the discord user" do
      user = create(:esm_dev)
      user = ESM::User.find_by_discord_id(user.discord_id).discord_user

      expect(user).not_to be_nil
    end

    it "should cache data" do
      user = create(:esm_dev)
      user = ESM::User.find_by_discord_id(user.discord_id)
      discord_user = user.discord_user

      expect(discord_user).not_to be_nil
      expect(discord_user.instance_variable_get("@esm_user")).to eql(user)
      expect(discord_user.instance_variable_get("@steam_uid")).to eql(user.steam_uid)
    end
  end

  describe "#parse" do
    it "should parse steam_uid" do
      create(:esm_dev)
      user = ESM::User.parse(TestUser::User1::STEAM_UID).discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(TestUser::User1::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(TestUser::User1::ID)
    end

    it "should parse discord_id" do
      create(:esm_dev)
      user = ESM::User.parse(TestUser::User1::ID).discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(TestUser::User1::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(TestUser::User1::ID)
    end

    it "should parse discord_tag" do
      create(:esm_dev)
      user = ESM::User.parse("<@#{TestUser::User1::ID}>").discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(TestUser::User1::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(TestUser::User1::ID)
    end

    it "should parse discord_tag (nickname)" do
      create(:esm_dev)
      user = ESM::User.parse("<@!#{TestUser::User1::ID}>").discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(TestUser::User1::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(TestUser::User1::ID)
    end

    it "should parse discord_tag (bot?)" do
      create(:esm_dev)
      user = ESM::User.parse("<@&#{TestUser::User1::ID}>").discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(TestUser::User1::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(TestUser::User1::ID)
    end

    it "should fail parse and return nil" do
      create(:esm_dev)
      expect(ESM::User.parse("test")).to be_nil
      expect(ESM::User.parse(TestUser::User1::STEAM_UID[1..-1])).to be_nil
    end

    it "should have no steam uid" do
      unregistered_user = create(:esm_dev, :unregistered)
      user = ESM::User.find_by_discord_id(unregistered_user.discord_id).discord_user

      expect(user).not_to be_nil
      expect(user.steam_uid).to be_nil
      expect(user.esm_user.id).to eql(unregistered_user.id)
    end

    it "should handle parsing an int" do
      unregistered_user = create(:esm_dev, :unregistered)
      user = ESM::User.find_by_discord_id(unregistered_user.discord_id).discord_user

      expect(user).not_to be_nil
      expect(user.steam_uid).to be_nil
      expect(user.esm_user.id).to eql(unregistered_user.id)
    end
  end

  describe "#registered?" do
    it "should respond" do
      user = create(:esm_dev)
      expect(user.respond_to?(:registered?)).to be(true)
    end

    it "should be registered" do
      registered_user = create(:esm_dev)
      user = ESM::User.find_by_discord_id(registered_user.discord_id).discord_user

      expect(user).not_to be_nil
      expect(user.steam_uid).to eql(registered_user.steam_uid)
      expect(user.esm_user.id).to eql(registered_user.id)
    end

    it "should not be registered" do
      unregistered_user = create(:esm_dev, :unregistered)
      user = ESM::User.find_by_discord_id(unregistered_user.discord_id).discord_user

      expect(user).not_to be_nil
      expect(user.steam_uid).to be_nil
      expect(user.esm_user.id).to eql(unregistered_user.id)
    end
  end

  describe "#developer?" do
    it "should be true" do
      user = build(:esm_dev)
      expect(user.developer?).to be(true)
    end

    it "should be false" do
      user = build(:user)
      expect(user.developer?).to be(false)
    end
  end
end
