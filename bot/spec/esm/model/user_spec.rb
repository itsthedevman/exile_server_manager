# frozen_string_literal: true

describe ESM::User do
  describe "#parse" do
    it "should parse steam_uid" do
      create(:esm_dev)
      user = ESM::User.parse(ESM::User::Bryan::STEAM_UID).discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(ESM::User::Bryan::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(ESM::User::Bryan::ID)
    end

    it "should parse discord_id" do
      create(:esm_dev)
      user = ESM::User.parse(ESM::User::Bryan::ID).discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(ESM::User::Bryan::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(ESM::User::Bryan::ID)
    end

    it "should parse discord_tag" do
      create(:esm_dev)
      user = ESM::User.parse("<@#{ESM::User::Bryan::ID}>").discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(ESM::User::Bryan::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(ESM::User::Bryan::ID)
    end

    it "should parse discord_tag (nickname)" do
      create(:esm_dev)
      user = ESM::User.parse("<@!#{ESM::User::Bryan::ID}>").discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(ESM::User::Bryan::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(ESM::User::Bryan::ID)
    end

    it "should parse discord_tag (bot?)" do
      create(:esm_dev)
      user = ESM::User.parse("<@&#{ESM::User::Bryan::ID}>").discord_user

      expect(user).not_to be_nil
      expect(user.esm_user.steam_uid).to eql(ESM::User::Bryan::STEAM_UID)
      expect(user.esm_user.discord_id).to eql(ESM::User::Bryan::ID)
    end

    it "should fail parse and return nil" do
      create(:esm_dev)
      expect(ESM::User.parse("test")).to be_nil
      expect(ESM::User.parse(ESM::User::Bryan::STEAM_UID[1..-1])).to be_nil
    end

    it "should have no steam uid" do
      unregistered_user = create(:esm_dev, :unregistered)
      user = ESM::User.parse(unregistered_user.discord_id.to_s).discord_user

      expect(user).not_to be_nil
      expect(user.steam_uid).to be_nil
      expect(user.esm_user.id).to eql(unregistered_user.id)
    end

    it "should handle parsing an int" do
      unregistered_user = create(:esm_dev, :unregistered)
      user = ESM::User.parse(unregistered_user.discord_id).discord_user

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
      user = ESM::User.parse(registered_user.discord_id).discord_user

      expect(user).not_to be_nil
      expect(user.steam_uid).to eql(registered_user.steam_uid)
      expect(user.esm_user.id).to eql(registered_user.id)
    end

    it "should not be registered" do
      unregistered_user = create(:esm_dev, :unregistered)
      user = ESM::User.parse(unregistered_user.discord_id).discord_user

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
