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

  def allow_access(denied:, reason: nil)
    verdict =
      if denied
        ESM::Command::Permission::Result.new(reason:, detail: nil)
      else
        ESM::Command::Permission::ALLOWED
      end

    allow(ESM::CommandAccess).to receive(:new).and_return(instance_double(ESM::CommandAccess, verdict:))
  end

  describe "GET show" do
    it "lands on the community's tools" do
      allow_access(denied: true, reason: :not_allowlisted)

      get "/communities/#{community.public_id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Community-wide tools for #{community.community_id}")
    end

    # Matched with the closing quote because every other sidebar entry is this path plus a segment, so a bare
    # substring would pass on Commands or Notifications alone.
    it "offers the page in the sidebar" do
      allow_access(denied: true, reason: :not_allowlisted)

      get "/communities/#{community.public_id}"

      expect(response.body).to include(%(href="#{community_path(community.public_id)}"))
    end

    context "when the viewer can broadcast" do
      before { allow_access(denied: false) }

      it "offers the tool and the modal to compose one in" do
        get "/communities/#{community.public_id}"

        expect(response.body).to include("Compose a broadcast")
        expect(response.body).to include("broadcast-modal")
      end

      it "offers the community's servers as audiences" do
        get "/communities/#{community.public_id}"

        expect(response.body).to include(server.public_id)
      end
    end

    context "when the viewer cannot broadcast" do
      before { allow_access(denied: true, reason: :not_allowlisted) }

      # A tool the viewer can't run is absent rather than disabled, so the page never advertises something that
      # would be refused on submit.
      it "shows the empty state instead of the tool" do
        get "/communities/#{community.public_id}"

        expect(response.body).to include("Nothing to run here yet")
        expect(response.body).not_to include("Compose a broadcast")
      end
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the environment is not local" do
      before { allow(Rails.env).to receive(:local?).and_return(false) }

      it "opens the community on its settings, the way it always has" do
        get "/communities/#{community.public_id}"

        expect(response).to redirect_to(edit_community_path(community.public_id))
      end
    end
  end
end
