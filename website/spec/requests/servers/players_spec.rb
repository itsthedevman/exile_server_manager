# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Servers::Players", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before do
    sign_in user

    # The player snapshot and the online check are NATS reads against the game
    # server; stub both so the pages render their offline state without the bot.
    allow_any_instance_of(ESM::Server).to receive(:player_info).and_return(nil)
    allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
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

  # The full /me page renders the whole server-hub shell, which fans out into more
  # game-server reads than a controller spec should stub. summary (the lazy card)
  # exercises the same load path in isolation; the auth guard is checked on /me.
  it "renders the lazy summary card" do
    get "/servers/#{server.public_id}/players/summary"

    expect(response).to have_http_status(:ok)
  end

  it "requires a signed-in user" do
    sign_out user
    get "/servers/#{server.public_id}/players/me"

    expect(response).to redirect_to("/login")
  end

  describe "GET me" do
    it "404s when the player can't access the me command" do
      allow_access(denied: true, reason: :disabled)

      get "/servers/#{server.public_id}/players/me"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST reset_me" do
    def post_reset(idempotency_key: SecureRandom.uuid)
      post "/servers/#{server.public_id}/players/reset_me",
        params: {idempotency_key:, dom_id: "player_actions"},
        as: :turbo_stream
    end

    before do
      allow(ESM::Service::API).to receive(:call) do |_action, command_id:|
        ESM::ServiceCommand.find(command_id).completed!
      end
      allow(Poll).to receive(:until)
    end

    it "dispatches a stuck command for the current player" do
      allow_access(denied: false)

      expect { post_reset }.to change(ESM::ServiceCommand, :count).by(1)

      command = ESM::ServiceCommand.last
      expect(command.command_name).to eq("stuck")
      expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    it "rejects a denied reset with a 422 and never dispatches one" do
      allow_access(denied: true, reason: :server_offline)

      expect { post_reset }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
    end
  end
end
