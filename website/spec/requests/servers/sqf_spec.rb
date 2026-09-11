# frozen_string_literal: true

RSpec.describe "Servers::Sqf", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before do
    sign_in user

    # Boundary stubs - never touch NATS, don't wait on a settle.
    allow(ESM::Service::API).to receive(:call)
    allow(Poll).to receive(:until)
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

  # No JS in a request spec, so the editor/target widgets don't fire their formdata sync; post the resolved params the
  # controller reads directly (code_to_execute + target), exactly as the browser would after the sync.
  def post_sqf(code: "player setDamage 0;", target: "server", idempotency_key: SecureRandom.uuid)
    post "/servers/#{server.public_id}/sqf",
      params: {code_to_execute: code, target:, idempotency_key:},
      as: :turbo_stream
  end

  describe "POST /sqf" do
    it "dispatches an sqf command carrying the code and target" do
      allow_access(denied: false)

      expect { post_sqf(code: "hint 'hi';", target: "76561198000000042") }.to change(ESM::ServiceCommand, :count).by(1)

      command = ESM::ServiceCommand.last
      expect(command.command_name).to eq("sqf")
      expect(command.arguments).to include(
        server_id: server.server_id,
        community_id: community.community_id,
        code_to_execute: "hint 'hi';",
        target: "76561198000000042"
      )
      expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    it "defaults a blank target to the whole server" do
      allow_access(denied: false)

      post_sqf(target: "")

      expect(ESM::ServiceCommand.last.arguments).to include(target: "server")
    end

    it "rejects a denied run with a 422 and never creates a command" do
      allow_access(denied: true, reason: :not_allowlisted)

      expect { post_sqf }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
    end

    it "redirects an unregistered user to register" do
      sign_in create(:user, steam_uid: nil)

      post_sqf

      expect(response).to redirect_to(register_path)
    end

    it "refuses to run sqf on an outdated server" do
      # sqf locks its allowlist by default, so access is granted outright here - otherwise a denial could come from
      # either gate and this wouldn't prove require_supported_server! is the one doing the refusing.
      allow_access(denied: false)
      allow(Rails.env).to receive(:local?).and_return(false)
      server.update!(server_version: "2.0.0")

      expect { post_sqf }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Regression test for the crash the audit reproduced: current_server is nil for an unknown server_id and nothing
    # guards that before CommandAccess builds its gate off it, so this raises ArgumentError instead of 404ing.
    it "404s (not 500s) an sqf run on a server that doesn't exist" do
      pending("HOLE (permission audit decision 4): SqfController#create doesn't guard current_server.nil? before " \
        "checking command access, so this raises ArgumentError instead of 404ing")

      post "/servers/#{SecureRandom.uuid}/sqf",
        params: {code_to_execute: "player setDamage 0;", target: "server", idempotency_key: SecureRandom.uuid},
        as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end

    # This runs through the real CommandAccess/Permission#resolve and the fake bot rather than allow_access's stub,
    # so it has to undo the describe block's blanket ESM::Service::API.call stub first - otherwise community
    # membership and server connectivity would both resolve from that bare double instead of service_api.
    it "refuses a registered non-member when the community's sqf allowlist is off" do
      pending("HOLE (permission audit decision 1): allowlist_enabled: false admits any registered user, not just " \
        "this community's members - Community#membership_for folds a non-member's nil payload into role_ids: [], " \
        "administrator: false, and Permission#resolve reads an empty allowlist as open to everyone")

      allow(ESM::Service::API).to receive(:call) { |action, **payload| service_api.call(action, **payload) }
      service_api.server_connected = true
      service_api.answer(:community_membership, nil)

      create(:command_configuration, community:, command_name: "sqf", allowlist_enabled: false)

      expect { post_sqf }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET status" do
    def get_status(public_id)
      get "/servers/#{server.public_id}/sqf/commands/#{public_id}/status", as: :turbo_stream
    end

    it "serves the caller's own command by its public id" do
      command = create(:service_command, user:, server:, command_name: "sqf")
      get_status(command.public_id)

      expect(response).to have_http_status(:ok)
    end

    it "renders the returned value when the run succeeds" do
      command = create(:service_command, user:, server:, command_name: "sqf")
      command.update!(result: {type: "bool", result: true}, status: :completed)

      get_status(command.public_id)

      expect(response.body).to include("Returned")
      expect(response.body).to include("sqf-output")
    end

    it "renders an execution error when the extension nulls both the type and the result" do
      command = create(:service_command, user:, server:, command_name: "sqf")
      command.update!(result: {type: nil, result: nil}, status: :completed)

      get_status(command.public_id)

      expect(response.body).to include("It may be invalid")
    end

    it "404s a command that belongs to another user" do
      other = create(:service_command, server:, user: create(:user), command_name: "sqf")
      get_status(other.public_id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
