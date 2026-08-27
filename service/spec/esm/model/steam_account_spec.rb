# frozen_string_literal: true

describe ESM::SteamAccount do
  let!(:steam) { described_class.new(Faker::Steam.uid) }

  it "is valid" do
    expect(steam).not_to be_nil
    expect(steam.send(:summary)).not_to be_nil
    expect(steam.send(:bans)).not_to be_nil
  end

  it "returns the profile's visibility" do
    expect(steam.profile_visibility).to be_in(["Private", "Friends Only", "Public"])
  end

  describe "#to_h" do
    it "projects every field the website reads" do
      expect(steam.to_h.keys).to contain_exactly(
        :username, :avatar, :profile_url, :profile_visibility, :profile_created_at,
        :community_banned, :vac_banned, :number_of_vac_bans, :days_since_last_ban
      )
    end

    # This hash is handed straight to UserSteamData.new and #update, so a key it does not carry as an attribute
    # raises UnknownAttributeError on the next Steam refresh, nowhere near this class.
    it "keys itself to UserSteamData's attributes" do
      expect(steam.to_h.keys).to match_array(ESM::UserSteamData.new.to_h.keys)
    end
  end
end
