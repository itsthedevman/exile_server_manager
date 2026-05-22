# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::CommunityChannels do
  describe ".call" do
    let(:discord_server) { build(:discord_server, channels: %i[general logging]) }
    let!(:community) { create(:community, discord_server: discord_server) }

    it "returns channels grouped with an uncategorized fallback in front" do
      result = described_class.call(id: community.id, user_id: nil)
      expect(result).to be_an(Array)
      expect(result.first.first[:name]).to eq(community.community_name)
      expect(result.first.last).to all(include(type: :text))
    end

    context "when the community is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1, user_id: nil)).to be_nil
      end
    end
  end
end
