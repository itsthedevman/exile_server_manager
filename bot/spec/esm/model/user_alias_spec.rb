# frozen_string_literal: true

describe ESM::UserAlias do
  let!(:user) { ESM::Test.user }
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let(:second_community) { ESM::Test.second_community }
  let(:second_server) { ESM::Test.second_server }

  it "is valid" do
    expect {
      create(:user_alias, user: user, server: server, value: "1")
      create(:user_alias, user: user, community: community, value: "2")
    }.not_to raise_error
  end

  it "does not allow an alias to be duplicated for a server or a community" do
    # The same alias can exist for both server and community
    expect {
      create(:user_alias, user: user, server: server, value: "1")
      create(:user_alias, user: user, community: community, value: "1")
    }.not_to raise_error

    # But it cannot be shared between communities
    expect {
      create(:user_alias, user: user, community: community, value: "2")
      create(:user_alias, user: user, community: second_community, value: "2")
    }.to raise_error(ActiveRecord::RecordInvalid)

    # Or between the same community
    expect {
      create(:user_alias, user: user, community: community, value: "3")
      create(:user_alias, user: user, community: community, value: "3")
    }.to raise_error(ActiveRecord::RecordInvalid)

    # And same thing for server
    expect {
      create(:user_alias, user: user, server: server, value: "4")
      create(:user_alias, user: user, server: second_server, value: "4")
    }.to raise_error(ActiveRecord::RecordInvalid)

    # Same server, same error
    expect {
      create(:user_alias, user: user, server: server, value: "5")
      create(:user_alias, user: user, server: server, value: "5")
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
