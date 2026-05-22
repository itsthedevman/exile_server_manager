# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::CommunityModifiableBy do
  describe ".call" do
    let(:discord_user) { build(:discord_user) }
    let(:discord_server) { build(:discord_server, owner: discord_user) }
    let!(:community) { create(:community, discord_server: discord_server) }
    let!(:user) { create(:user, discord_user: discord_user) }

    it "returns true when the user owns the community's guild" do
      expect(described_class.call(id: community.id, user_id: user.id)).to be(true)
    end

    it "returns false for a non-owner user" do
      other_user = create(:user, :with_discord_member, discord_server: discord_server)
      expect(described_class.call(id: community.id, user_id: other_user.id)).to be(false)
    end

    context "when the community is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1, user_id: user.id)).to be_nil
      end
    end

    context "when the user is missing" do
      it "returns nil" do
        expect(described_class.call(id: community.id, user_id: -1)).to be_nil
      end
    end
  end
end
