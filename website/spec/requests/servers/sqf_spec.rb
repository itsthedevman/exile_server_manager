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
