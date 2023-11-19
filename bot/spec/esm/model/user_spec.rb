# frozen_string_literal: true

describe ESM::User do
  let!(:esm_user) { ESM::Test.user }
  let!(:discord_user) { esm_user.discord_user }
  let(:unregistered_user) { ESM::Test.user(:unregistered) }

  it "create a UserDefault" do
    expect(esm_user.id_defaults).not_to be(nil)
    expect(esm_user.id_defaults.server_id).to be(nil)
    expect(esm_user.id_defaults.community_id).to be(nil)
  end

  describe "#discord_user" do
    it "returns the discord user" do
      expect(discord_user).not_to be_nil
    end

    it "caches data" do
      expect(discord_user).not_to be_nil
      expect(discord_user.instance_variable_get(:@esm_user)).to eq(esm_user)
    end
  end

  describe ".parse" do
    it "parses steam_uid" do
      parsed_user = ESM::User.parse(esm_user.steam_uid)
      expect(parsed_user).to eq(esm_user)
    end

    it "parses discord_id" do
      parsed_user = ESM::User.parse(discord_user.id)
      expect(parsed_user).to eq(esm_user)
    end

    it "parses discord_tag" do
      parsed_user = ESM::User.parse("<@#{discord_user.id}>")
      expect(parsed_user).to eq(esm_user)
    end

    it "parses discord_tag (nickname)" do
      parsed_user = ESM::User.parse("<@!#{discord_user.id}>")
      expect(parsed_user).to eq(esm_user)
    end

    it "parses discord_tag (bot?)" do
      parsed_user = ESM::User.parse("<@&#{discord_user.id}>")
      expect(parsed_user).to eq(esm_user)
    end

    it "fails parsing and returns nil" do
      expect(ESM::User.parse("test")).to be_nil
      expect(ESM::User.parse(esm_user.steam_uid[1..])).to be_nil
    end
  end

  describe ".find_by_discord_id" do
    it "has no steam uid" do
      queried_user = ESM::User.find_by_discord_id(unregistered_user.discord_id)
      expect(queried_user).to eq(unregistered_user)
    end

    it "handles parsing an int" do
      queried_user = ESM::User.find_by_discord_id(unregistered_user.discord_id.to_i)
      expect(queried_user).to eq(unregistered_user)
    end
  end

  describe "#registered?" do
    it "respond" do
      expect(esm_user.respond_to?(:registered?)).to be(true)
    end

    it "is registered" do
      expect(esm_user.registered?).to be(true)
    end

    it "is not registered" do
      expect(unregistered_user.registered?).to eq(false)
    end
  end

  describe "#developer?" do
    let!(:developer_user) { ESM::Test.user(type: :developer) }

    it "is a developer" do
      expect(developer_user.developer?).to be(true)
    end

    it "is not a developer" do
      esm_user.steam_uid = "a"
      expect(esm_user.developer?).to be(false)
    end
  end
end
