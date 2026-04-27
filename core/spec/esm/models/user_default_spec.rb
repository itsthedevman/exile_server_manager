# frozen_string_literal: true

RSpec.describe ESM::UserDefault do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community: community) }
  let!(:user) { create(:user) }

  it "can be created with community and server" do
    expect {
      create(:user_default, user: user, community: community, server: server)
    }.not_to raise_error
  end

  it "can be created with just a community (server is optional)" do
    result = create(:user_default, user: user, community: community)
    expect(result.server_id).to be_nil
  end

  it "can be created with just a user (community and server are optional)" do
    result = create(:user_default, user: user)
    expect(result.community_id).to be_nil
    expect(result.server_id).to be_nil
  end
end
