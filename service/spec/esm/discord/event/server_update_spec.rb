# frozen_string_literal: true

describe ESM::Discord::Event::ServerUpdate do
  let(:discord_user) { build(:discord_user) }
  let(:discord_server) { build(:discord_server, owner: discord_user) }

  let!(:user) { create(:user, discord_user: discord_user) }
  let!(:community) { create(:community, discord_server:) }

  subject(:event) { described_class.new(discord_server) }

  context "when the server's owner already matches" do
    before do
      community.update!(owner_user_id: user.id)
    end

    it "is expected to not change the owner_user_id" do
      expect(community.owner_user_id).to eq(user.id)

      event.run!

      community.reload
      expect(community.owner_user_id).to eq(user.id)
    end
  end

  context "when the server's owner_user_id does not match the owner's" do
    let!(:different_user) { create(:user) }

    before do
      community.update!(owner_user_id: different_user.id)
    end

    it "is expected to set the owner_user_id" do
      expect(community.owner_user_id).to eq(different_user.id)

      event.run!

      community.reload
      expect(community.owner_user_id).to eq(user.id)
    end
  end
end
