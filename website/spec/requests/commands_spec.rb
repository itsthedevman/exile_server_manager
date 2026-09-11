# frozen_string_literal: true

RSpec.describe "Commands", type: :request do
  let(:community) { create(:community, player_mode_enabled: false) }
  let(:user) { create(:user) }
  let(:modifiable) { true }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(modifiable)
  end

  describe "GET index" do
    it "renders the community's command configuration" do
      get "/communities/#{community.public_id}/commands"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Command Configuration")
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}/commands"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        get "/communities/#{community.public_id}/commands"

        expect(response).to redirect_to(edit_community_path(community.public_id))
        expect(flash[:alert]).to match(/player mode is enabled/i)
      end
    end
  end

  describe "PATCH update" do
    # Community#create_command_configurations seeds one row per command on creation (community.rb:61,192), so the
    # row under test already exists rather than being built fresh here - building another would just be a second,
    # ambiguous row for the same community/command pair.
    let(:command_configuration) { community.command_configurations.find_by!(command_name: "broadcast") }

    def patch_command(name: "broadcast", **params)
      patch "/communities/#{community.public_id}/commands/#{name}",
        params: {command_configuration: {enabled: "1"}.merge(params)}
    end

    it "updates the community's configuration for the named command" do
      expect { patch_command(cooldown_quantity: "5", cooldown_type: "minutes") }
        .to change { command_configuration.reload.cooldown_quantity }.to(5)

      expect(response).to have_http_status(:ok)
    end

    it "is not found when no configuration exists for the named command" do
      patch_command(name: "does_not_exist")

      expect(response).to have_http_status(:not_found)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found and leaves the configuration untouched" do
        expect { patch_command(cooldown_quantity: "5") }
          .not_to change { command_configuration.reload.cooldown_quantity }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        patch_command

        expect(response).to redirect_to(edit_community_path(community.public_id))
        expect(flash[:alert]).to match(/player mode is enabled/i)
      end
    end
  end
end
