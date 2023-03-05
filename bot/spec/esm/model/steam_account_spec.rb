# frozen_string_literal: true

describe ESM::SteamAccount do
  let!(:steam) { described_class.new(ESM::Test.steam_uid) }

  it "is valid" do
    expect(steam).not_to be_nil
    expect(steam.send(:summary)).not_to be_nil
    expect(steam.send(:bans)).not_to be_nil
  end

  it "returns the profile's visibility" do
    expect(steam.profile_visibility).to be_in(["Private", "Friends Only", "Public"])
  end
end
