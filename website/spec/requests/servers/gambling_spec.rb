# frozen_string_literal: true

RSpec.describe "Servers::Gambling", type: :request do
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

  def post_gamble(amount: "100", idempotency_key: SecureRandom.uuid)
    post "/servers/#{server.public_id}/gamble",
      params: {amount:, idempotency_key:},
      as: :turbo_stream
  end

  describe "POST /gamble" do
    it "dispatches a gamble command carrying the bet amount" do
      allow_access(denied: false)

      expect { post_gamble(amount: "250") }.to change(ESM::ServiceCommand, :count).by(1)

      command = ESM::ServiceCommand.last
      expect(command.command_name).to eq("gamble")
      expect(command.arguments).to include(
        server_id: server.server_id,
        community_id: community.community_id,
        amount: "250"
      )
      expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    it "rejects a denied bet with a 422 and never creates a command" do
      allow_access(denied: true, reason: :disabled)

      expect { post_gamble }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
    end

    it "redirects an unregistered user to register" do
      sign_in create(:user, steam_uid: nil)

      post_gamble

      expect(response).to redirect_to(register_path)
    end

    it "refuses to gamble on an outdated server" do
      allow(Rails.env).to receive(:local?).and_return(false)
      server.update!(server_version: "2.0.0")

      expect { post_gamble }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Regression test for the crash the audit reproduced: current_server is nil for an unknown server_id and nothing
    # guards that before CommandAccess builds its gate off it, so this raises ArgumentError instead of 404ing.
    it "404s (not 500s) a gamble on a server that doesn't exist" do
      pending("HOLE (permission audit decision 4): GamblingController#create doesn't guard current_server.nil? " \
        "before checking command access, so this raises ArgumentError instead of 404ing")

      post "/servers/#{SecureRandom.uuid}/gamble",
        params: {amount: "100", idempotency_key: SecureRandom.uuid},
        as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET status" do
    def get_status(public_id)
      get "/servers/#{server.public_id}/gamble/commands/#{public_id}/status", as: :turbo_stream
    end

    it "serves the caller's own command by its public id" do
      command = create(:service_command, user:, server:, command_name: "gamble")
      get_status(command.public_id)

      expect(response).to have_http_status(:ok)
    end

    it "404s a command that belongs to another user" do
      other = create(:service_command, server:, user: create(:user), command_name: "gamble")
      get_status(other.public_id)

      expect(response).to have_http_status(:not_found)
    end

    # Regression test for the crash the audit reproduced: the command lookup is scoped to the caller, not the URL's
    # server_id, so an owned command reached through a bogus server_id still resolves - and then gamble_stat calls
    # current_server.id on nil instead of 404ing.
    it "404s (not 500s) when the URL's server doesn't exist" do
      pending("HOLE (permission audit decision 4): #status's gamble_stat calls current_server.id without checking " \
        "current_server.nil? first, so this raises NoMethodError instead of 404ing")

      command = create(:service_command, user:, server:, command_name: "gamble")
      get "/servers/#{SecureRandom.uuid}/gamble/commands/#{command.public_id}/status", as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end
end
