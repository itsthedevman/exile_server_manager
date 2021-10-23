# frozen_string_literal: true

describe ESM::SteamAccount do
  let!(:steam) { described_class.new(TestUser::User1::STEAM_UID) }

  it "is valid" do
    expect(steam).not_to be_nil
    expect(steam.send(:summary)).not_to be_nil
    expect(steam.send(:bans)).not_to be_nil
  end

  it "should return 'Public'" do
    expect(steam.profile_visibility).to eql("Public")
  end
end
