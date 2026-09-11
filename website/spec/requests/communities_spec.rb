# frozen_string_literal: true

RSpec.describe "Communities", type: :request do
  let(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let(:user) { create(:user) }
  let(:modifiable) { true }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(modifiable)
  end

  describe "GET show" do
    it "opens the community on its settings" do
      get "/communities/#{community.public_id}"

      expect(response).to redirect_to(edit_community_path(community.public_id))
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET edit" do
    subject(:body) do
      get "/communities/#{community.public_id}/edit"
      response.body
    end

    context "when the owner may change the community's type" do
      let(:community) { create(:community, owner_user_id: user.id, player_mode_enabled: false) }
      let!(:server) { nil }

      it "offers the switch and the modal to confirm it in" do
        expect(body).to include("Switch to a player community")
        expect(body).to include('id="change-mode-modal"')
      end
    end

    context "when the community still has servers" do
      let(:community) { create(:community, owner_user_id: user.id, player_mode_enabled: false) }

      # The modal is what performs the change, so a locked card must not ship one for a stray anchor to open.
      it "explains why instead of offering the switch" do
        expect(body).to include("Remove this community&#39;s servers first")
        expect(body).not_to include('id="change-mode-modal"')
      end
    end

    context "when the user can edit the community but does not own it" do
      it "names ownership as the reason" do
        expect(body).to include("Only the community owner can change this")
        expect(body).not_to include('id="change-mode-modal"')
      end
    end
  end

  describe "PATCH update" do
    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      # check_for_community_access! runs before the community_id branch that would otherwise blow up on a missing
      # param, so the deny state doesn't need a well-formed body to prove.
      it "is not found and leaves the community untouched" do
        expect {
          patch "/communities/#{community.public_id}", params: {community: {welcome_message: "changed"}}
        }.not_to change { community.reload.welcome_message }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE destroy" do
    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found and never asks the community to leave" do
        expect_any_instance_of(ESM::Community).not_to receive(:leave)

        delete "/communities/#{community.public_id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    # The worked TRUSTED example from the audit: the website's own gate passes, but the bot is the final say on
    # whether the community may actually be removed.
    context "when the bot refuses to remove the community" do
      it "is not found and logs the failure" do
        allow_any_instance_of(ESM::Community).to receive(:leave).and_return(false)
        expect(ESM.logger).to receive(:error!).with(hash_including(message: "Failed to delete community"))

        delete "/communities/#{community.public_id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET available" do
    it "reports availability for a manager" do
      get "/communities/#{community.public_id}/available", params: {id: "brandnew"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("available" => true)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}/available", params: {id: "brandnew"}

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
