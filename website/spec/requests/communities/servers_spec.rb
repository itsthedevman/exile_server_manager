# frozen_string_literal: true

RSpec.describe "Communities::Servers", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  def base_path
    "/communities/#{community.public_id}/servers"
  end

  # `target` lets the cross-community examples address a server through a community that does not own it.
  def server_path(suffix = nil, target: server)
    path = "#{base_path}/#{target.public_id}"
    suffix ? "#{path}/#{suffix}" : path
  end

  def create_params(**overrides)
    {server: {server_id: "created", server_ip: "127.0.0.1", server_port: "2302"}.merge(overrides)}
  end

  def update_params(**overrides)
    {
      server: {
        server_id: "updated", server_ip: "127.0.0.1", server_port: "2302",
        # An empty hash serializes to nothing over the wire, so server_settings needs at least one key present or
        # permit never sees the param at all and sanitize_setting_params blows up on a nil.
        server_settings: {number_locale: "en"}
      }.merge(overrides)
    }
  end

  # Every action the controller exposes, run against whichever server/community the example has set up. Shared by
  # both denial contexts so each one walks the exact same list.
  def show_request(target: server) = get server_path(target:)
  def new_request = get "#{base_path}/new"
  def create_request = post base_path, params: create_params
  def edit_request(target: server) = get server_path("edit", target:)
  def update_request(target: server) = patch server_path(target:), params: update_params, as: :turbo_stream
  def destroy_request(target: server) = delete server_path(target:)
  def enable_v2_request(target: server) = patch server_path("enable_v2", target:)
  def disable_v2_request(target: server) = patch server_path("disable_v2", target:)
  def key_request(target: server) = get server_path("key", target:)
  def server_token_request(target: server) = get server_path("server_token", target:)
  # Plain path, no format: the not_found rescue handler only answers html/json/turbo_stream, and a yml request
  # against it 406s rather than 404s, which would say nothing about whether the guard itself held.
  def server_config_request(target: server) = get server_path("server_config", target:)
  def available_request(target: server) = get server_path("available", target:)

  # The real route: config.yml only renders as yaml, so proving the guard's positive path needs the extension.
  def server_config_yml_request(target: server) = get "#{server_path(target:)}/server_config.yml"

  describe "when nobody is signed in" do
    it "sends every action to the login page instead of the server" do
      show_request
      expect(response).to redirect_to(login_path)

      new_request
      expect(response).to redirect_to(login_path)

      create_request
      expect(response).to redirect_to(login_path)

      edit_request
      expect(response).to redirect_to(login_path)

      update_request
      expect(response).to redirect_to(login_path)

      destroy_request
      expect(response).to redirect_to(login_path)

      enable_v2_request
      expect(response).to redirect_to(login_path)

      disable_v2_request
      expect(response).to redirect_to(login_path)

      available_request
      expect(response).to redirect_to(login_path)
    end

    # These three hand out live credentials, so a signed-out request refusing to leak them into the response body
    # matters more than the redirect status by itself.
    it "does not leak the key, token or config to a signed-out request" do
      key_request
      expect(response.body).not_to include(server.server_key)

      server_token_request
      expect(response.body).not_to include(server.server_key)

      server_config_request
      expect(response.body).not_to include(server.server_key)
    end
  end

  describe "when the viewer cannot manage the community" do
    before do
      sign_in user
      allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(false)
    end

    it "404s show" do
      show_request
      expect(response).to have_http_status(:not_found)
    end

    it "404s new" do
      new_request
      expect(response).to have_http_status(:not_found)
    end

    it "404s create and writes nothing" do
      expect { create_request }.not_to change(ESM::Server, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "404s edit" do
      edit_request
      expect(response).to have_http_status(:not_found)
    end

    it "404s update and leaves the server untouched" do
      expect { update_request }.not_to change { server.reload.server_id }
      expect(response).to have_http_status(:not_found)
    end

    it "404s destroy and leaves the server in place" do
      server
      expect { destroy_request }.not_to change(ESM::Server, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "404s enable_v2" do
      enable_v2_request
      expect(response).to have_http_status(:not_found)
    end

    it "404s disable_v2" do
      disable_v2_request
      expect(response).to have_http_status(:not_found)
    end

    it "404s available" do
      available_request
      expect(response).to have_http_status(:not_found)
    end

    it "404s key, server_token and server_config, and never puts the secret in the body" do
      key_request
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(server.server_key)

      server_token_request
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(server.server_key)

      server_config_request
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(server.server_key)
    end
  end

  describe "when the viewer manages this community" do
    before do
      sign_in user
      allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(true)
    end

    it "redirects show to the edit page" do
      show_request
      expect(response).to redirect_to(edit_community_server_path(community, server))
    end

    it "opens the new server form" do
      new_request
      expect(response).to have_http_status(:ok)
    end

    it "opens the edit form for this community's own server" do
      edit_request
      expect(response).to have_http_status(:ok)
    end

    # The sidebar only lists servers for a community that runs them, which is the only place the link could be
    describe "the dashboard link" do
      let(:community) { create(:community, player_mode_enabled: false) }

      it "sits on a v2 server's row in the sidebar" do
        server.update!(ui_version: ServerVersion::MINIMUM_SERVER_VERSION)

        edit_request
        expect(response.body).to include(%(href="/servers/#{server.public_id}"))
      end

      it "is left off a classic server's row, since its dashboard only asks it to update" do
        server.update!(ui_version: "1.0.0")

        edit_request
        expect(response.body).not_to include(%(href="/servers/#{server.public_id}"))
      end
    end

    it "hands over the raw server key" do
      key_request
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(server.server_key)
    end

    it "hands over the access/secret token" do
      server_token_request
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(server.token.to_json)
    end

    it "hands over a rendered config.yml carrying the server's own settings" do
      server.server_setting.update!(database_uri: "mysql://esm:s3cr3t@10.0.0.5/exile")

      server_config_yml_request
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("mysql://esm:s3cr3t@10.0.0.5/exile")
    end

    describe "cross-community scoping" do
      let(:other_community) { create(:community) }
      let(:other_server) { create(:server, community: other_community) }

      # modifiable_by? is stubbed true for every community above, so these examples isolate the boundary that remains:
      # find_server scoping the lookup to current_community.servers.
      it "does not reach another community's server through edit" do
        get "#{base_path}/#{other_server.public_id}/edit"
        expect(response).to have_http_status(:not_found)
      end

      it "does not update another community's server, and leaves it untouched" do
        expect {
          patch "#{base_path}/#{other_server.public_id}", params: update_params, as: :turbo_stream
        }.not_to change { other_server.reload.server_id }

        expect(response).to have_http_status(:not_found)
      end

      it "does not destroy another community's server" do
        other_server
        expect { delete "#{base_path}/#{other_server.public_id}" }.not_to change(ESM::Server, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "does not flip another community's server to the v2 UI" do
        patch "#{base_path}/#{other_server.public_id}/enable_v2"
        expect(response).to have_http_status(:not_found)
        expect(other_server.reload.ui_version).not_to eq("2.0.0")
      end

      it "does not flip another community's server back to the v1 UI" do
        other_server.update!(ui_version: "2.0.0")

        patch "#{base_path}/#{other_server.public_id}/disable_v2"
        expect(response).to have_http_status(:not_found)
        expect(other_server.reload.ui_version).to eq("2.0.0")
      end

      it "does not check availability against another community's server" do
        get "#{base_path}/#{other_server.public_id}/available"
        expect(response).to have_http_status(:not_found)
      end

      it "does not hand over another community's server key" do
        get "#{base_path}/#{other_server.public_id}/key"
        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include(other_server.server_key)
      end

      it "does not hand over another community's server token" do
        get "#{base_path}/#{other_server.public_id}/server_token"
        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include(other_server.server_key)
      end

      it "does not hand over another community's rendered config" do
        other_server.server_setting.update!(database_uri: "mysql://esm:other-secret@10.0.0.9/exile")

        get "#{base_path}/#{other_server.public_id}/server_config"
        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include("other-secret")
      end

      # Same scoping, the other direction: this community's own id paired with a server that belongs elsewhere.
      it "refuses this community's own URL when the server id in it belongs to another community" do
        get "/communities/#{other_community.public_id}/servers/#{server.public_id}/edit"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "mass assignment" do
      it "cannot smuggle a new server into another community on create" do
        other_community = create(:community)

        post base_path, params: create_params(community_id: other_community.id)

        created = ESM::Server.find_by(server_id: "#{community.community_id}_created")
        expect(created).to be_present
        expect(created.community_id).to eq(community.id)
      end

      it "cannot move an existing server to another community on update" do
        other_community = create(:community)

        patch server_path, params: update_params(community_id: other_community.id), as: :turbo_stream

        expect(server.reload.community_id).to eq(community.id)
      end

      it "cannot overwrite the server's key by naming it directly in the update form" do
        original_key = server.server_key

        patch server_path, params: update_params(server_key: "attacker-supplied-key"), as: :turbo_stream

        expect(server.reload.server_key).to eq(original_key)
      end
    end
  end
end
