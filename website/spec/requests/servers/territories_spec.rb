# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Servers::Territories", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  # The current territory id lives in the URL; the controller reads it back from the
  # doubled route param (`:territory_territory_id`) as old_territory_id.
  let(:territory_id) { "oldbase" }

  before do
    sign_in user

    # Boundary stubs. The real call is a blocking NATS request/reply whose bot-side
    # handler marks the row non-pending; mirror that so idempotency behaves as it
    # does in production. Poll is skipped so specs don't wait on a settle.
    allow(ESM::Service::API).to receive(:call) do |_action, command_id:|
      ESM::ServerCommand.find(command_id).dispatched!
    end
    allow(Poll).to receive(:until)
  end

  def post_set_id(custom_id:, idempotency_key: SecureRandom.uuid)
    post "/servers/#{server.public_id}/territories/#{territory_id}/set_id",
      params: {custom_id:, idempotency_key:, dom_id: "set_id_modal_#{territory_id}"},
      as: :turbo_stream
  end

  describe "POST /set_id" do
    it "creates a set_id command wired from the request params and dispatches it" do
      expect { post_set_id(custom_id: "newbase") }.to change(ESM::ServerCommand, :count).by(1)

      command = ESM::ServerCommand.last
      expect(command).to have_attributes(user_id: user.id, command_name: "set_id")
      expect(command.arguments).to include(
        old_territory_id: territory_id,
        new_territory_id: "newbase",
        server_id: server.server_id,
        community_id: community.community_id
      )

      expect(ESM::Service::API).to have_received(:call).with(:server_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    it "dedupes on idempotency_key so a double-submit fires the command once" do
      key = SecureRandom.uuid

      expect do
        post_set_id(custom_id: "newbase", idempotency_key: key)
        post_set_id(custom_id: "newbase", idempotency_key: key)
      end.to change(ESM::ServerCommand, :count).by(1)

      expect(ESM::Service::API).to have_received(:call).once
    end

    it "requires a signed-in user" do
      sign_out user
      post_set_id(custom_id: "newbase")

      expect(response).to redirect_to("/login")
    end
  end
end
