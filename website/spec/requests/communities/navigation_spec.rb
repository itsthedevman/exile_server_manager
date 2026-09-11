# frozen_string_literal: true

# The community sidebar gates its entries on command_accessible?, and it is rendered by controllers that never
# dispatch a command. Adding a gated entry to it therefore breaks pages nothing else in this suite loads: the nav is
# shared, so its requirements are everyone's requirements. These load each of those pages for that reason alone.
RSpec.describe "Communities navigation", type: :request do
  # The factory leaves player_mode_enabled unset, and the commands and notifications pages redirect away under it,
  # which would let this whole group pass without ever rendering the nav it exists to load.
  let(:community) { create(:community, player_mode_enabled: false) }
  let!(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(true)

    # Allowed rather than denied on purpose: a denial hides the gated nav entries, which is the branch that was
    # already working. Rendering them is what exercises the gate these pages had no way to call.
    allow(ESM::CommandAccess).to receive(:new)
      .and_return(instance_double(ESM::CommandAccess, verdict: ESM::Command::Permission::ALLOWED))
  end

  {
    "the settings page" => "/edit",
    "the commands page" => "/commands",
    "the notifications page" => "/notifications",
    "the XM8 routing page" => "/notification_routes",
    "the cooldowns page" => "/cooldowns",
    "the new server page" => "/servers/new"
  }.each do |name, path|
    it "renders #{name}" do
      get "/communities/#{community.public_id}#{path}"

      expect(response).to have_http_status(:ok)

      # The sidebar's own id, asserted because a redirect or an error page would otherwise satisfy a status check
      # while skipping the partial this group exists to render.
      expect(response.body).to include("dashboard-sidebar")
    end
  end

  describe "the Tools card" do
    # Broadcast opens over whichever page is showing, so its entry targets the modal's frame and the modal ships with
    # the sidebar rather than with any one page.
    it "offers broadcast as a modal" do
      get "/communities/#{community.public_id}/edit"

      expect(response.body).to include("bi-lightning-charge")
      expect(response.body).to include(%(href="#{new_community_broadcast_path(community.public_id)}"))
      expect(response.body).to include(%(id="broadcast_modal_frame"))
    end

    context "when the viewer can use none of the tools" do
      before do
        server.update!(ui_version: "1.0.0")

        allow(ESM::CommandAccess).to receive(:new).and_return(
          instance_double(
            ESM::CommandAccess,
            verdict: ESM::Command::Permission::Result.new(reason: :not_allowlisted, detail: nil)
          )
        )
      end

      it "leaves the card out" do
        get "/communities/#{community.public_id}/edit"

        expect(response.body).not_to include("bi-lightning-charge")
        expect(response.body).not_to include(%(id="broadcast_modal_frame"))
      end
    end
  end
end
