# frozen_string_literal: true

RSpec.describe ESM::Regex do
  describe "DISCORD_ID" do
    it "matches valid Discord IDs (18+ digits not starting with 0)" do
      # Discord IDs are snowflakes - 18+ digits, not starting with 0
      expect("123456789012345678").to match(described_class::DISCORD_ID_ONLY)
      expect("1234567890123456789").to match(described_class::DISCORD_ID_ONLY)
    end

    it "does not match IDs starting with 0" do
      expect("012345678901234567").not_to match(described_class::DISCORD_ID_ONLY)
    end

    it "does not match short IDs (less than 18 digits)" do
      expect("12345678901234567").not_to match(described_class::DISCORD_ID_ONLY)
    end

    it "matches within a string (non-anchored version)" do
      expect("user id: 123456789012345678").to match(described_class::DISCORD_ID)
    end
  end

  describe "DISCORD_TAG" do
    it "matches standard user mentions" do
      expect("<@123456789012345678>").to match(described_class::DISCORD_TAG)
    end

    it "matches nickname mentions" do
      expect("<@!123456789012345678>").to match(described_class::DISCORD_TAG)
    end

    it "matches role mentions" do
      expect("<@&123456789012345678>").to match(described_class::DISCORD_TAG)
    end

    it "does not match plain text" do
      expect("@user").not_to match(described_class::DISCORD_TAG_ONLY)
    end
  end

  describe "STEAM_UID" do
    it "matches valid Steam UIDs starting with 7656" do
      expect("76561198012345678").to match(described_class::STEAM_UID)
      expect("76561234567890123").to match(described_class::STEAM_UID)
    end

    it "does not match IDs not starting with 7656" do
      expect("12345678901234567").not_to match(described_class::STEAM_UID_ONLY)
      expect("76551198012345678").not_to match(described_class::STEAM_UID_ONLY)
    end
  end

  describe "SERVER_ID" do
    it "matches valid server IDs with underscore" do
      expect("esm_malden").to match(described_class::SERVER_ID)
      expect("test_server_name").to match(described_class::SERVER_ID)
      expect("a_b").to match(described_class::SERVER_ID)
    end

    it "does not match IDs without underscore" do
      expect("esmmalden").not_to match(described_class::SERVER_ID_ONLY)
      expect("server").not_to match(described_class::SERVER_ID_ONLY)
    end
  end

  describe "TERRITORY_ID" do
    it "matches alphanumeric territory IDs" do
      expect("Territory1").to match(described_class::TERRITORY_ID)
      expect("base_alpha").to match(described_class::TERRITORY_ID)
      expect("12345").to match(described_class::TERRITORY_ID)
    end
  end

  describe "HEX_COLOR" do
    it "matches valid hex colors" do
      expect("#FF5733").to match(described_class::HEX_COLOR)
      expect("#ffffff").to match(described_class::HEX_COLOR)
      expect("#000000").to match(described_class::HEX_COLOR)
      expect("#1e354d").to match(described_class::HEX_COLOR)
    end

    it "does not match invalid hex colors" do
      expect("FF5733").not_to match(described_class::HEX_COLOR)
      expect("#FFF").not_to match(described_class::HEX_COLOR)
      expect("#GGGGGG").not_to match(described_class::HEX_COLOR)
    end
  end

  describe "FLAG_NAME" do
    it "captures flag names from .paa files" do
      match = "flag_usa.paa".match(described_class::FLAG_NAME)
      expect(match[1]).to eq("flag_usa")
    end

    it "does not match non-flag files" do
      expect("texture.paa").not_to match(described_class::FLAG_NAME)
    end
  end

  describe "LOG_TIMESTAMP" do
    it "captures time and zone from log entries" do
      log_line = "[14:30:45:123456 +02:00] [thread 1] Some message"
      match = log_line.match(described_class::LOG_TIMESTAMP)

      expect(match[:time]).to eq("14:30:45")
      expect(match[:zone]).to eq("+02:00")
    end

    it "handles negative timezone offsets" do
      log_line = "[08:15:30:000000 -05:00] [thread 2] Message"
      match = log_line.match(described_class::LOG_TIMESTAMP)

      expect(match[:zone]).to eq("-05:00")
    end
  end

  describe "TARGET" do
    it "matches Discord tags" do
      expect("<@123456789012345678>").to match(described_class::TARGET)
    end

    it "matches Discord IDs" do
      expect("123456789012345678").to match(described_class::TARGET)
    end

    it "matches Steam UIDs" do
      expect("76561198012345678").to match(described_class::TARGET)
    end
  end

  describe "BROADCAST" do
    it "matches 'all'" do
      expect("all").to match(described_class::BROADCAST)
    end

    it "matches 'preview'" do
      expect("preview").to match(described_class::BROADCAST)
    end

    it "matches server IDs" do
      expect("esm_malden").to match(described_class::BROADCAST)
    end

    it "matches local IDs without community prefix" do
      expect("malden").to match(described_class::BROADCAST)
    end
  end
end
