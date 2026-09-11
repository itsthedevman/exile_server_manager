# frozen_string_literal: true

RSpec.describe "Channels", type: :request do
  let(:community) { create(:community) }
  let(:user) { create(:user) }
  let(:modifiable) { true }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(modifiable)

    service_api.channels = [[{name: "Text Channels"}, [{id: "1", name: "general"}]]]
  end

  # This controller's own routing quirk (channels_controller.rb:38-53): the URL segment here is the community's
  # plaintext community_id, not its public_id the way every other community route reads it - convert_community_id
  # translates it into a public_id before either branch runs.
  describe "GET index" do
    context "without ?user" do
      it "returns the full channel list for a manager" do
        get "/communities/#{community.community_id}/channels"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("content", "channels")).to be_present
      end

      context "when the viewer cannot modify the community" do
        let(:modifiable) { false }

        it "is not found" do
          get "/communities/#{community.community_id}/channels"

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "with ?user" do
      # Permission checking for this branch is delegated to the bot (channels_controller.rb:11), on purpose, so a
      # viewer who could not pass check_for_community_access! still reaches it. modifiable is forced false here,
      # not just left at the outer default, so this actually proves the branch skips that gate rather than merely
      # not needing it this time.
      let(:modifiable) { false }

      it "does not require manager status, trusting the bot's own answer instead" do
        get "/communities/#{community.community_id}/channels", params: {user: "1"}

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("content", "channels")).to be_present
      end

      it "is not found when the community_id in the URL does not resolve to a community" do
        get "/communities/does-not-exist/channels", params: {user: "1"}

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
