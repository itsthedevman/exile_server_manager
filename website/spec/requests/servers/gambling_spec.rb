# frozen_string_literal: true

require "rails_helper"

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
    verdict = double("verdict", denied?: denied, reason:)
    allow(ESM::CommandAccess).to receive(:new).and_return(double("access", verdict:))
  end

  def post_gamble(amount: "100", idempotency_key: SecureRandom.uuid)
    post "/servers/#{server.public_id}/gamble",
      params: {amount:, idempotency_key:},
      as: :turbo_stream
  end

  describe "POST /gamble" do
    it "dispatches a gamble command carrying the bet amount" do
      allow_access(denied: false)

      expect { post_gamble(amount: "250") }.to change(ESM::ServerCommand, :count).by(1)

      command = ESM::ServerCommand.last
      expect(command.command_name).to eq("gamble")
      expect(command.arguments).to include(
        server_id: server.server_id,
        community_id: community.community_id,
        amount: "250"
      )
      expect(ESM::Service::API).to have_received(:call).with(:server_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    it "rejects a denied bet with a 422 and never creates a command" do
      allow_access(denied: true, reason: :disabled)

      expect { post_gamble }.not_to change(ESM::ServerCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
    end
  end

  describe "GET status" do
    def get_status(public_id)
      get "/servers/#{server.public_id}/gamble/commands/#{public_id}/status", as: :turbo_stream
    end

    it "serves the caller's own command by its public id" do
      command = create(:server_command, user:, server:, command_name: "gamble")
      get_status(command.public_id)

      expect(response).to have_http_status(:ok)
    end

    it "404s a command that belongs to another user" do
      other = create(:server_command, server:, user: create(:user), command_name: "gamble")
      get_status(other.public_id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
