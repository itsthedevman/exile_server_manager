# frozen_string_literal: true

describe Discordrb::User do
  let!(:esm_user) { ESM::Test.user }
  let!(:discord_user) { esm_user.discord_user }

  describe "#steam_uid" do
    it "responds" do
      expect(discord_user.respond_to?(:steam_uid)).to be(true)
    end

    it "gets and sets" do
      steam_uid = ESM::Test.steam_uid
      discord_user.steam_uid = steam_uid
      expect(discord_user.steam_uid).to eq(steam_uid)
    end
  end

  describe "#esm_user" do
    it "responds" do
      expect(discord_user.respond_to?(:esm_user)).to be(true)
    end

    it "gets and sets" do
      discord_user.instance_variable_set(:@esm_user, esm_user)
      expect(discord_user.esm_user.id).to eq(esm_user.id)
    end
  end
end
