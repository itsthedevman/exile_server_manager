# frozen_string_literal: true

describe ESM::Regex do
  describe "COMMUNITY_ID" do
    it "should parse" do
      expect(ESM::Regex::COMMUNITY_ID =~ "esm").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "esm1").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "test").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "testing").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "1337").not_to be_nil
      expect(ESM::Regex::COMMUNITY_ID =~ "foo_bar").not_to be_nil
    end
  end

  describe "DISCORD_TAG" do
    it "should parse" do
      expect(ESM::Regex::DISCORD_TAG =~ "<@137709767954137088>").not_to be_nil

      # With a custom name
      expect(ESM::Regex::DISCORD_TAG =~ "<@!477847544521687040>").not_to be_nil
    end
  end

  describe "DISCORD_ID" do
    it "should parse" do
      expect(ESM::Regex::DISCORD_ID =~ ESM::User::Bryan::ID).not_to be_nil
      expect(ESM::Regex::DISCORD_ID =~ "477847544521687040").not_to be_nil
    end
  end

  describe "STEAM_UID" do
    it "should parse" do
      expect(ESM::Regex::STEAM_UID =~ ESM::User::Bryan::STEAM_UID).not_to be_nil
    end
  end

  describe "DISCORD_TAG_ONLY" do
    it "should parse" do
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "<@#{ESM::User::Bryan::ID}>").not_to be_nil

      # With a custom name
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "<@!477847544521687040>").not_to be_nil
    end

    it "should not parse" do
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "Hello <@#{ESM::User::Bryan::ID}>!").to be_nil

      # With a custom name
      expect(ESM::Regex::DISCORD_TAG_ONLY =~ "Hello <@!477847544521687040>!").to be_nil
    end
  end

  describe "DISCORD_ID_ONLY" do
    it "should parse" do
      expect(ESM::Regex::DISCORD_ID_ONLY =~ ESM::User::Bryan::ID).not_to be_nil
      expect(ESM::Regex::DISCORD_ID_ONLY =~ "477847544521687040").not_to be_nil
    end

    it "should not parse" do
      expect(ESM::Regex::DISCORD_ID_ONLY =~ "<@#{ESM::User::Bryan::ID}>").to be_nil
      expect(ESM::Regex::DISCORD_ID_ONLY =~ "<@!477847544521687040>").to be_nil
    end
  end

  describe "STEAM_UID_ONLY" do
    it "should parse" do
      expect(ESM::Regex::STEAM_UID_ONLY =~ ESM::User::Bryan::STEAM_UID).not_to be_nil
    end

    it "should not parse" do
      expect(ESM::Regex::STEAM_UID_ONLY =~ "Steam UID: #{ESM::User::Bryan::STEAM_UID}").to be_nil
    end
  end

  describe "TARGET" do
    it "should parse" do
      expect(ESM::Regex::TARGET =~ ESM::User::Bryan::ID).not_to be_nil
      expect(ESM::Regex::TARGET =~ "<@477847544521687040>").not_to be_nil
      expect(ESM::Regex::TARGET =~ "<@!477847544521687040>").not_to be_nil
      expect(ESM::Regex::TARGET =~ ESM::User::Bryan::STEAM_UID).not_to be_nil
    end
  end

  describe "SERVER_ID" do
    it "should parse" do
      expect(ESM::Regex::SERVER_ID =~ "hello esm_malden").not_to be_nil
      expect(ESM::Regex::SERVER_ID =~ "aws_awesome").not_to be_nil
      expect(ESM::Regex::SERVER_ID =~ "o_o").not_to be_nil
    end

    it "should not parse" do
      expect(ESM::Regex::SERVER_ID =~ "esm").to be_nil
      expect(ESM::Regex::SERVER_ID =~ "_test").to be_nil
    end
  end

  describe "SERVER_ID_ONLY" do
    it "should parse" do
      expect(ESM::Regex::SERVER_ID_ONLY =~ "esm_malden").not_to be_nil
    end

    it "should not parse" do
      expect(ESM::Regex::SERVER_ID_ONLY =~ "ServerID: esm_malden").to be_nil
    end
  end

  describe "TERRITORY_ID" do
    it "should parse" do
      expect(ESM::Regex::TERRITORY_ID =~ "abcde").not_to be_nil
      expect(ESM::Regex::TERRITORY_ID =~ "my_awesome_territory").not_to be_nil
    end
  end

  describe "TERRITORY_ID_ONLY" do
    it "should parse" do
      expect(ESM::Regex::TERRITORY_ID_ONLY =~ "abcde").not_to be_nil
    end

    it "should not parse" do
      expect(ESM::Regex::TERRITORY_ID_ONLY =~ "TerritoryID: my_awesome_territory").to be_nil
    end
  end

  describe "FLAG_NAME" do
    it "should parse" do
      expect(ESM::Regex::FLAG_NAME =~ "\\A3\\Data_F\\Flags\\flag_us_co.paa").not_to be_nil
      expect(ESM::Regex::FLAG_NAME =~ "exile_assets\\texture\\flag\\flag_misc_knuckles_co.paa").not_to be_nil
    end
  end

  describe "BROADCAST" do
    it "should parse" do
      expect(ESM::Regex::BROADCAST =~ "esm_malden").not_to be_nil
      expect(ESM::Regex::BROADCAST =~ "all").not_to be_nil
      expect(ESM::Regex::BROADCAST =~ "preview").not_to be_nil
    end
  end

  describe "HEX_COLOR" do
    it "should parse" do
      expect(ESM::Regex::HEX_COLOR =~ "#ffffff").not_to be_nil
      expect(ESM::Regex::HEX_COLOR =~ ESM::Color::BLUE).not_to be_nil
      expect(ESM::Regex::HEX_COLOR =~ "red").to be_nil
    end
  end
end
