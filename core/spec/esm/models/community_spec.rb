# frozen_string_literal: true

RSpec.describe ESM::Community do
  describe ".find_by_server_id" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }

    it "finds the community by a server id" do
      result = described_class.find_by_server_id(server.server_id)
      expect(result).not_to be_nil
      expect(result).to eq(community)
    end

    it "returns nil when given nil" do
      expect(described_class.find_by_server_id(nil)).to be_nil
    end

    it "returns nil when given empty string" do
      expect(described_class.find_by_server_id("")).to be_nil
    end

    it "returns nil when server_id doesn't exist" do
      expect(described_class.find_by_server_id("nonexistent_server")).to be_nil
    end

    it "returns nil for malformed server_id" do
      expect(described_class.find_by_server_id("invalid")).to be_nil
    end
  end

  describe "#owned_by?" do
    let(:community) { create(:community) }
    let(:user) { create(:user) }

    it "is true for the owner" do
      community.update!(owner_user_id: user.id)

      expect(community.owned_by?(user)).to be(true)
    end

    it "is false for someone else" do
      community.update!(owner_user_id: create(:user).id)

      expect(community.owned_by?(user)).to be(false)
    end

    it "is false for a nil user" do
      community.update!(owner_user_id: user.id)

      expect(community.owned_by?(nil)).to be(false)
    end

    # nil == nil is true, so a community whose owner was never backfilled would otherwise hand ownership to any
    # caller that is itself id-less.
    it "is false when neither side has an id" do
      community.update!(owner_user_id: nil)

      expect(community.owned_by?(ESM::User.new)).to be(false)
    end
  end

  describe "#can_enable_player_mode?" do
    let(:community) { create(:community) }

    it "is true when the community has no servers" do
      expect(community.can_enable_player_mode?).to be(true)
    end

    it "is false once a server is registered" do
      create(:server, community:)

      expect(community.can_enable_player_mode?).to be(false)
    end
  end
end
