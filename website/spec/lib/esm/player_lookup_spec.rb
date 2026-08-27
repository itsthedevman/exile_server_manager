# frozen_string_literal: true

RSpec.describe ESM::PlayerLookup do
  describe ".call" do
    it "takes a bare Steam UID at face value" do
      result = described_class.call("76561198037177305")

      expect(result).to be_steam_uid
      expect(result.steam_uid).to eq("76561198037177305")
    end

    it "treats anything that identifies nobody in particular as a name" do
      expect(described_class.call("Dave")).to be_name
    end

    # Short enough that no ID could be it, so it is a name that happens to be digits rather than a malformed ID.
    it "treats a number too short to be an ID as a name" do
      expect(described_class.call("12345")).to be_name
    end

    it "reads an empty query as nothing asked" do
      expect(described_class.call("   ")).to be_blank
      expect(described_class.call(nil)).to be_blank
    end

    it "keeps the query it was handed, trimmed" do
      expect(described_class.call("  Dave  ").query).to eq("Dave")
    end

    # The anchoring test. Core's *_ONLY patterns anchor per line, so this string satisfies them on its second line
    # while its visible text is a name - which would send an admin to the wrong player's page.
    it "does not read a UID smuggled onto a second line as a UID" do
      expect(described_class.call("Dave\n76561198037177305")).to be_name
    end

    context "with a Discord ID" do
      it "follows a registered account through to its Steam UID" do
        user = create(:user)

        result = described_class.call(user.discord_id)

        expect(result).to be_steam_uid
        expect(result.steam_uid).to eq(user.steam_uid)
        expect(result.discord_id).to eq(user.discord_id)
      end

      # Registration is what links the two halves, so an account that never linked Steam has no UID to reach and no
      # player page to land on. Distinct from having no account at all.
      it "separates an account with no Steam link from no account at all" do
        user = create(:user, steam_uid: nil)

        expect(described_class.call(user.discord_id)).to be_unregistered
        expect(described_class.call("800000000000009999")).to be_unknown
      end
    end

    context "with a mention" do
      it "resolves the id inside it" do
        user = create(:user)

        expect(described_class.call("<@#{user.discord_id}>").steam_uid).to eq(user.steam_uid)
      end

      # Discord writes the wrapper several ways depending on what is being mentioned; the digits are the id in each.
      it "reads the ! and & forms the same way" do
        user = create(:user)

        expect(described_class.call("<@!#{user.discord_id}>").steam_uid).to eq(user.steam_uid)
        expect(described_class.call("<@&#{user.discord_id}>").steam_uid).to eq(user.steam_uid)
      end
    end
  end
end
