# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::UserCommunities do
  describe ".call" do
    let(:discord_user) { build(:discord_user) }
    let(:discord_server) { build(:discord_server, owner: discord_user) }
    let!(:community) { create(:community, discord_server: discord_server) }
    let!(:user) { create(:user, discord_user: discord_user) }

    it "returns the IDs of communities the user is a member of" do
      result = described_class.call(id: user.id, guild_ids: [discord_server.id.to_s])
      expect(result).to include(community.id)
    end

    it "returns an empty array when no guilds match" do
      expect(described_class.call(id: user.id, guild_ids: ["999"])).to eq([])
    end

    context "with check_for_perms" do
      let!(:user) { create(:user, :with_discord_member, discord_server: discord_server) }

      it "excludes communities the user can't modify" do
        result = described_class.call(id: user.id, guild_ids: [discord_server.id.to_s], check_for_perms: true)
        expect(result).not_to include(community.id)
      end
    end

    context "when the user is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1, guild_ids: [])).to be_nil
      end
    end
  end
end
