# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::CommunityMembership do
  describe ".call" do
    let(:discord_server) { build(:discord_server) }
    let!(:community) { create(:community, discord_server: discord_server) }

    context "when the user holds roles in the community's guild" do
      let(:vip_role) { build(:discord_role, server: discord_server, name: "vip") }
      let!(:user) do
        create(:user, :with_discord_member, discord_server: discord_server, discord_member_roles: [vip_role])
      end

      it "returns the ids of the roles they hold, as strings" do
        result = described_class.call(user_id: user.id, community_id: community.id)

        expect(result[:role_ids]).to contain_exactly(vip_role.id.to_s)
      end

      it "reports them as a non-administrator" do
        result = described_class.call(user_id: user.id, community_id: community.id)

        expect(result[:administrator]).to be(false)
      end
    end

    context "when the user holds a role granting administrator" do
      # 8 is Discord's administrator permission bit.
      let(:admin_role) { build(:discord_role, server: discord_server, name: "admin", permissions: 8) }
      let!(:user) do
        create(:user, :with_discord_member, discord_server: discord_server, discord_member_roles: [admin_role])
      end

      it "reports them as an administrator" do
        result = described_class.call(user_id: user.id, community_id: community.id)

        expect(result[:administrator]).to be(true)
      end
    end

    context "when the user holds no roles" do
      let!(:user) { create(:user, :with_discord_member, discord_server: discord_server, discord_member_roles: []) }

      it "returns an empty role list and no administrator" do
        result = described_class.call(user_id: user.id, community_id: community.id)

        expect(result).to eq({role_ids: [], administrator: false})
      end
    end

    context "when the user is not a member of the community's guild" do
      let!(:user) { create(:user) }

      it "returns nil instead of raising" do
        expect(described_class.call(user_id: user.id, community_id: community.id)).to be_nil
      end
    end

    context "when the community is missing" do
      let!(:user) { create(:user) }

      it "returns nil" do
        expect(described_class.call(user_id: user.id, community_id: -1)).to be_nil
      end
    end

    context "when the user is missing" do
      it "returns nil" do
        expect(described_class.call(user_id: -1, community_id: community.id)).to be_nil
      end
    end
  end
end
