# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::CommunityRoles do
  describe ".call" do
    let(:discord_server) { build(:discord_server, roles: %i[member moderator]) }
    let!(:community) { create(:community, discord_server: discord_server) }

    it "returns selectable roles excluding @everyone" do
      result = described_class.call(id: community.id)
      names = result.map { |r| r[:name] }
      expect(names).to include("member", "moderator")
      expect(names).not_to include("@everyone")
    end

    it "shapes each role with id/name/color/disabled" do
      result = described_class.call(id: community.id)
      expect(result.first.keys).to contain_exactly(:id, :name, :color, :disabled)
    end

    context "when the community is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1)).to be_nil
      end
    end
  end
end
