# frozen_string_literal: true

describe ESM::Regex do
  let(:user) { ESM::Test.user }

  describe "COMMUNITY_ID" do
    it "parses" do
      expect(ESM::Regex::COMMUNITY_ID =~ "esm").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "esm1").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "test").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "testing").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "1337").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "foo_bar").not_to be_nil
    end
  end

  describe "DISCORD_TAG" do
    it "parses" do
      expect(ESM::Regex::DISCORD_TAG =~ user.mention).not_to be_nil

      # With a custom name
      expect(ESM::Regex::DISCORD_TAG =~ "<@!#{user.discord_id}>").not_to be_nil
    end
  end

  describe "DISCORD_ID" do
    it "parses" do
      expect(ESM::Regex::DISCORD_ID =~ user.discord_id).not_to be_nil
      expect(ESM::Regex::DISCORD_ID =~ "1#{user.discord_id}").not_to be_nil # max 19 characters (because uint64)
    end
  end

  describe "STEAM_UID" do
    it "parses" do
      expect(ESM::Regex::STEAM_UID =~ user.steam_uid).not_to be_nil
    end
  end

  describe "DISCORD_TAG_ONLY" do
    it "parses" do
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "<@#{user.discord_id}>").not_to be_nil

      # With a custom name
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "<@!#{user.discord_id}>").not_to be_nil
    end

    it "does not parse" do
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "Hello <@1#{user.discord_id}>!").to be_nil

      # With a custom name
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "Hello <@!#{user.discord_id}>!").to be_nil
    end
  end

  describe "DISCORD_ID_ONLY" do
    it "parses" do
      expect(ESM::Regex::DISCORD_ID_ONLY =~ user.discord_id).not_to be_nil
      expect(ESM::Regex::DISCORD_ID_ONLY =~ "1#{user.discord_id}").not_to be_nil
    end

    it "does not parse" do
      expect(ESM::Regex::DISCORD_ID_ONLY =~ "<@#{user.discord_id}>").to be_nil
      expect(ESM::Regex::DISCORD_ID_ONLY =~ "<@!#{user.discord_id}>").to be_nil
    end
  end

  describe "STEAM_UID_ONLY" do
    it "parses" do
      expect(ESM::Regex::STEAM_UID_ONLY =~ user.steam_uid).not_to be_nil
    end

    it "does not parse" do
      expect(ESM::Regex::STEAM_UID_ONLY =~ "Steam UID: #{user.steam_uid}").to be_nil
    end
  end

  describe "TARGET" do
    it "parses" do
      expect(ESM::Regex::TARGET =~ user.discord_id).not_to be_nil
      expect(ESM::Regex::TARGET =~ "<@#{user.discord_id}>").not_to be_nil
      expect(ESM::Regex::TARGET =~ "<@!#{user.discord_id}>").not_to be_nil
      expect(ESM::Regex::TARGET =~ user.steam_uid).not_to be_nil
    end
  end

  describe "SERVER_ID" do
    it "parses" do
      expect(ESM::Regex::SERVER_ID =~ "hello esm_malden").not_to be_nil
      expect(ESM::Regex::SERVER_ID =~ "aws_awesome").not_to be_nil
      expect(ESM::Regex::SERVER_ID =~ "o_o").not_to be_nil
    end

    it "does not parse" do
      expect(ESM::Regex::SERVER_ID =~ "esm").to be_nil
      expect(ESM::Regex::SERVER_ID =~ "_test").to be_nil
    end
  end

  describe "SERVER_ID_ONLY" do
    it "parses" do
      expect(ESM::Regex::SERVER_ID_ONLY =~ "esm_malden").not_to be_nil
    end

    it "does not parse" do
      expect(ESM::Regex::SERVER_ID_ONLY =~ "ServerID: esm_malden").to be_nil
    end
  end

  describe "TERRITORY_ID" do
    it "parses" do
      expect(ESM::Regex::TERRITORY_ID =~ "abcde").not_to be_nil
      expect(ESM::Regex::TERRITORY_ID =~ "my_awesome_territory").not_to be_nil
    end
  end

  describe "TERRITORY_ID_ONLY" do
    it "parses" do
      expect(ESM::Regex::TERRITORY_ID_ONLY =~ "abcde").not_to be_nil
    end

    it "does not parse" do
      expect(ESM::Regex::TERRITORY_ID_ONLY =~ "TerritoryID: my_awesome_territory").to be_nil
    end
  end

  describe "FLAG_NAME" do
    it "parses" do
      expect(ESM::Regex::FLAG_NAME =~ "\\A3\\Data_F\\Flags\\flag_us_co.paa").not_to be_nil
      expect(ESM::Regex::FLAG_NAME =~ "exile_assets\\texture\\flag\\flag_misc_knuckles_co.paa").not_to be_nil
    end
  end

  describe "BROADCAST" do
    it "parses" do
      expect(ESM::Regex::BROADCAST =~ "esm_malden").not_to be_nil
      expect(ESM::Regex::BROADCAST =~ "all").not_to be_nil
      expect(ESM::Regex::BROADCAST =~ "preview").not_to be_nil
    end
  end

  describe "HEX_COLOR" do
    it "parses" do
      expect(ESM::Regex::HEX_COLOR =~ "#ffffff").not_to be_nil
      expect(ESM::Regex::HEX_COLOR =~ ESM::Color::BLUE).not_to be_nil
      expect(ESM::Regex::HEX_COLOR =~ "red").to be_nil
    end
  end

  describe "TARGET_OR_TERRITORY_ID" do
    it "parses"
  end

  describe "LOG_TIMESTAMP" do
    it "parses"
  end
end
