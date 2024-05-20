# frozen_string_literal: true

describe ESM::UserAlias do
  let!(:user) { ESM::Test.user }
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server(for: community) }
  let(:second_community) { ESM::Test.second_community }
  let(:second_server) { ESM::Test.server(for: second_community) }

  it "is valid" do
    expect {
      create(:user_alias, user: user, server: server, value: "1")
      create(:user_alias, user: user, community: community, value: "2")
    }.not_to raise_error
  end

  context "when a community and server share the same alias" do
    it "is allowed" do
      expect {
        create(:user_alias, user: user, server: server, value: "1")
        create(:user_alias, user: user, community: community, value: "1")
      }.not_to raise_error
    end
  end

  context "when an alias is already taken by a community" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, community: community, value: "2")
        create(:user_alias, user: user, community: second_community, value: "2")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when a community is given the same alias" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, community: community, value: "3")
        create(:user_alias, user: user, community: community, value: "3")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when an alias is already taken by a server" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, server: server, value: "4")
        create(:user_alias, user: user, server: second_server, value: "4")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when a server is given the same alias" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, server: server, value: "5")
        create(:user_alias, user: user, server: server, value: "5")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
