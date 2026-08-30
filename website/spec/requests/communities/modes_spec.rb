# frozen_string_literal: true

RSpec.describe "Communities::Modes", type: :request do
  let(:community) { create(:community, player_mode_enabled: false) }
  let(:user) { create(:user) }

  before do
    sign_in user
    community.update!(owner_user_id: user.id)

    # Dashboard access is the page's gate; ownership is this action's, and the two are deliberately different.
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(true)
  end

  def patch_change_mode(enabled)
    patch "/communities/#{community.public_id}/change_mode", params: {player_mode_enabled: enabled}
  end

  describe "PATCH /player_mode" do
    it "switches a server community to a player community" do
      expect { patch_change_mode("1") }.to change { community.reload.player_mode_enabled? }.from(false).to(true)

      expect(response).to redirect_to(edit_community_path(community))
    end

    it "switches a player community back to a server community" do
      community.update!(player_mode_enabled: true)

      expect { patch_change_mode("0") }.to change { community.reload.player_mode_enabled? }.from(true).to(false)
    end

    # button_to serializes the target state as a string, and "false" is truthy in Ruby. Casting rather than testing
    # the raw param is what keeps "switch this off" from reading as "switch this on".
    it "reads the string 'false' as off" do
      community.update!(player_mode_enabled: true)

      patch_change_mode("false")

      expect(response).to redirect_to(edit_community_path(community))
      expect(community.reload.player_mode_enabled?).to be(false)
    end

    context "when the community still has servers" do
      before { create(:server, community:) }

      it "refuses to enable player mode" do
        expect { patch_change_mode("1") }.not_to change { community.reload.player_mode_enabled? }

        expect(flash[:warn]).to match(/remove this community's servers/i)
      end

      it "still allows leaving player mode" do
        community.update!(player_mode_enabled: true)

        expect { patch_change_mode("0") }.to change { community.reload.player_mode_enabled? }.to(false)
      end
    end

    context "when the user is not the owner" do
      before { community.update!(owner_user_id: create(:user).id) }

      it "is not found, even though they can edit everything else on the page" do
        expect { patch_change_mode("1") }.not_to change { community.reload.player_mode_enabled? }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community has no recorded owner" do
      before { community.update!(owner_user_id: nil) }

      it "is not found" do
        expect { patch_change_mode("1") }.not_to change { community.reload.player_mode_enabled? }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
