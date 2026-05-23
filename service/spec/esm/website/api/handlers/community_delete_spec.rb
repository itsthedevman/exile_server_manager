# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::CommunityDelete do
  describe ".call" do
    let(:discord_user) { build(:discord_user) }
    let(:discord_server) { build(:discord_server, owner: discord_user) }
    let!(:community) { create(:community, discord_server: discord_server) }
    let!(:user) { create(:user, discord_user: discord_user) }

    it "leaves the guild and destroys the community when the user can modify it" do
      expect(discord_server).to receive(:leave)
      expect { described_class.call(id: community.id, user_id: user.id) }
        .to change { ESM::Community.exists?(community.id) }.from(true).to(false)
    end

    context "when the user lacks modify permission" do
      let!(:user) { create(:user, :with_discord_member, discord_server: discord_server) }

      it "does not destroy the community" do
        expect(discord_server).not_to receive(:leave)
        expect { described_class.call(id: community.id, user_id: user.id) }
          .not_to change { ESM::Community.exists?(community.id) }
      end
    end

    context "when the community is missing" do
      it "returns nil" do
        expect(described_class.call(id: -1, user_id: user.id)).to be_nil
      end
    end
  end
end
