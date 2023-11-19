# frozen_string_literal: true

describe ESM::UserDefault do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:user) { ESM::Test.user }

  it "is valid" do
    expect {
      create(:user_default, user: user, community: community, server: server)

      # A default can be created for just a community
      result = create(:user_default, user: user, community: community)
      expect(result.server_id).to be(nil)
    }.not_to raise_error
  end
end
