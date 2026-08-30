# frozen_string_literal: true

RSpec.describe CommunitiesHelper, type: :helper do
  describe "#change_mode_lock_reason" do
    let(:owner) { create(:user) }
    let(:community) { create(:community, player_mode_enabled: false, owner_user_id: owner.id) }

    it "is nil for the owner of a server community with nothing registered" do
      expect(helper.change_mode_lock_reason(community, owner)).to be_nil
    end

    it "is nil for the owner of a player community even when the rule would block the other direction" do
      community.update!(player_mode_enabled: true)
      create(:server, community:)

      expect(helper.change_mode_lock_reason(community, owner)).to be_nil
    end

    it "names ownership for anyone who is not the owner" do
      expect(helper.change_mode_lock_reason(community, create(:user)))
        .to match(/only the community owner/i)
    end

    it "names the servers when a server community still has one" do
      create(:server, community:)

      expect(helper.change_mode_lock_reason(community, owner))
        .to match(/remove this community's servers/i)
    end

    # Ownership is checked first on purpose: telling a non-owner to go delete servers would be advice they cannot
    # act on and would not help them if they did.
    it "prefers the ownership reason when both apply" do
      create(:server, community:)

      expect(helper.change_mode_lock_reason(community, create(:user)))
        .to match(/only the community owner/i)
    end
  end
end
