# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::UserCommunityPermissions do
  describe ".call" do
    let(:discord_user) { build(:discord_user) }
    let(:discord_server) { build(:discord_server, owner: discord_user) }
    let!(:community) { create(:community, discord_server: discord_server) }
    let!(:user) { create(:user, discord_user: discord_user) }

    it "returns one entry per community with id and modifiable flag" do
      result = described_class.call(id: user.id, guild_ids: [discord_server.id.to_s])
      expect(result).to include(a_hash_including(id: community.id, modifiable: true))
    end

    it "returns an empty array when no guilds match" do
      expect(described_class.call(id: user.id, guild_ids: ["999"])).to eq([])
    end

    context "when the user is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1, guild_ids: [])).to be_nil
      end
    end
  end
end
