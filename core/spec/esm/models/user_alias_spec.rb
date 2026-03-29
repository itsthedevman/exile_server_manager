# frozen_string_literal: true

RSpec.describe ESM::UserAlias do
  let!(:user) { create(:user) }
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community: community) }
  let!(:second_community) { create(:community) }
  let!(:second_server) { create(:server, community: second_community) }

  it "is valid with server association" do
    expect {
      create(:user_alias, user: user, server: server, value: "1")
    }.not_to raise_error
  end

  it "is valid with community association" do
    expect {
      create(:user_alias, user: user, community: community, value: "2")
    }.not_to raise_error
  end

  context "when a community and server share the same alias value" do
    it "is allowed (different scopes)" do
      expect {
        create(:user_alias, user: user, server: server, value: "1")
        create(:user_alias, user: user, community: community, value: "1")
      }.not_to raise_error
    end
  end

  context "when an alias value is already taken by another community" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, community: community, value: "2")
        create(:user_alias, user: user, community: second_community, value: "2")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when a community already has that alias value" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, community: community, value: "3")
        create(:user_alias, user: user, community: community, value: "3")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when an alias value is already taken by another server" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, server: server, value: "4")
        create(:user_alias, user: user, server: second_server, value: "4")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when a server already has that alias value" do
    it "is not allowed" do
      expect {
        create(:user_alias, user: user, server: server, value: "5")
        create(:user_alias, user: user, server: server, value: "5")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
