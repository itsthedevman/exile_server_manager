# frozen_string_literal: true

RSpec.describe ESM::PlayerLookup do
  let(:community) { create(:community) }

  def lookup(query)
    described_class.call(query, community:)
  end

  describe ".call" do
    it "takes a bare Steam UID at face value" do
      result = lookup("76561198037177305")

      expect(result).to be_steam_uid
      expect(result.steam_uid).to eq("76561198037177305")
    end

    it "treats anything that identifies nobody in particular as a name" do
      expect(lookup("Dave")).to be_name
    end

    # Short enough that no ID could be it, so it is a name that happens to be digits rather than a malformed ID.
    it "treats a number too short to be an ID as a name" do
      expect(lookup("12345")).to be_name
    end

    it "reads an empty query as nothing asked" do
      expect(lookup("   ")).to be_blank
      expect(lookup(nil)).to be_blank
    end

    it "keeps the query it was handed, trimmed" do
      expect(lookup("  Dave  ").query).to eq("Dave")
    end

    # The anchoring test. Core's *_ONLY patterns anchor per line, so this string satisfies them on its second line
    # while its visible text is a name - which would send an admin to the wrong player's page.
    it "does not read a UID smuggled onto a second line as a UID" do
      expect(lookup("Dave\n76561198037177305")).to be_name
    end

    context "with a Discord ID belonging to a member of the community's Discord" do
      before do
        allow(community).to receive(:membership_for).and_return(Struct.new(:role_ids, :administrator).new([], false))
      end

      it "follows a registered account through to its Steam UID" do
        user = create(:user)

        result = lookup(user.discord_id)

        expect(result).to be_steam_uid
        expect(result.steam_uid).to eq(user.steam_uid)
        expect(result.discord_id).to eq(user.discord_id)
      end

      # Registration is what links the two halves, so an account that never linked Steam has no UID to reach and no
      # player page to land on. Distinct from having no account at all.
      it "separates an account with no Steam link from no account at all" do
        user = create(:user, steam_uid: nil)

        expect(lookup(user.discord_id)).to be_unregistered
        expect(lookup("800000000000009999")).to be_unknown
      end

      it "resolves the id inside a mention" do
        user = create(:user)

        expect(lookup("<@#{user.discord_id}>").steam_uid).to eq(user.steam_uid)
      end

      # Discord writes the wrapper several ways depending on what is being mentioned; the digits are the id in each.
      it "reads the ! and & forms of a mention the same way" do
        user = create(:user)

        expect(lookup("<@!#{user.discord_id}>").steam_uid).to eq(user.steam_uid)
        expect(lookup("<@&#{user.discord_id}>").steam_uid).to eq(user.steam_uid)
      end
    end

    # Following a Discord ID to a Steam UID is the pairing whois guards, held to the same line
    context "with a Discord ID belonging to someone outside the community's Discord" do
      before { allow(community).to receive(:membership_for).and_return(nil) }

      it "answers like an ID ESM has never seen, rather than reaching their Steam UID" do
        result = lookup(create(:user).discord_id)

        expect(result).to be_unknown
        expect(result.steam_uid).to be_nil
      end

      it "does not say whether they ever linked Steam" do
        expect(lookup(create(:user, steam_uid: nil).discord_id)).to be_unknown
      end
    end

    it "does not take a bot it cannot ask as a yes" do
      allow(community).to receive(:membership_for).and_raise(ESM::Service::API::Unreachable, "no responders")

      expect(lookup(create(:user).discord_id)).to be_unknown
    end
  end
end
