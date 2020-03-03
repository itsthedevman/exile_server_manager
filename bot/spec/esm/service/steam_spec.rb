# frozen_string_literal: true

describe ESM::Service::Steam do
  let!(:steam) { ESM::Service::Steam.new(ESM::User::Bryan::STEAM_UID) }

  it "should be valid" do
    expect(steam).not_to be_nil
  end

  it "should list player bans" do
    expect(steam.player_bans).not_to be_nil
  end

  it "should list player info" do
    expect(steam.player_info).not_to be_nil
  end

  it "should return 'Public'" do
    expect(steam.profile_visibility).to eql("Public")
  end
end
