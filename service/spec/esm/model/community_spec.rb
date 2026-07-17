# frozen_string_literal: true

RSpec.describe ESM::Community do
  describe "#territory_admin_users" do
    let(:discord_server) { build(:discord_server, channels: [:logging], roles: %i[territory_admin]) }
    let(:territory_admin_role) { discord_server.roles.find { |role| role.name == "territory_admin" } }
    let!(:community) { create(:community, discord_server:) }

    it "includes a registered member holding a role marked as a territory admin" do
      community.update!(territory_admin_ids: [territory_admin_role.id.to_s])
      admin = create(:user, :with_discord_member, discord_server:, discord_member_roles: [territory_admin_role])

      expect(community.territory_admin_users).to include(admin)
    end

    it "includes a registered member holding a role with the administrator permission" do
      # 0x8 is Discord's ADMINISTRATOR bit; such a role qualifies without being listed in territory_admin_ids.
      admin_role = build(:discord_role, server: discord_server, permissions: 8)
      admin = create(:user, :with_discord_member, discord_server:, discord_member_roles: [admin_role])

      expect(community.territory_admin_users).to include(admin)
    end

    it "excludes a member without a territory-admin or administrator role" do
      community.update!(territory_admin_ids: [territory_admin_role.id.to_s])
      member = create(:user, :with_discord_member, discord_server:)

      expect(community.territory_admin_users).not_to include(member)
    end

    it "always includes the registered guild owner" do
      owner = create(:user, discord_id: discord_server.owner.id.to_s)

      expect(community.territory_admin_users).to include(owner)
    end
  end
end
