# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::CommunityUsers do
  describe ".call" do
    let(:discord_server) { build(:discord_server) }
    let!(:community) { create(:community, discord_server: discord_server) }
    let!(:user) { create(:user, :with_discord_member, discord_server: discord_server) }

    it "returns the guild's users as hashes" do
      result = described_class.call(id: community.id)
      expect(result).to be_an(Array)
      expect(result).to all(be_a(Hash))
    end

    context "when the community is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1)).to be_nil
      end
    end
  end
end
