# frozen_string_literal: true

RSpec.describe "Communities::Broadcasts", type: :request do
  let(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(true)

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

  def post_broadcast(message: "Restarting in 15.", broadcast_to: server.public_id, idempotency_key: SecureRandom.uuid)
    post "/communities/#{community.public_id}/broadcast",
      params: {message:, broadcast_to:, idempotency_key:, dom_id: "broadcast_result"},
      as: :turbo_stream
  end

  describe "POST /broadcast" do
    it "dispatches a broadcast carrying the message and the resolved server" do
      allow_access(denied: false)

      expect { post_broadcast(message: "Wipe at 8.") }.to change(ESM::ServiceCommand, :count).by(1)

      command = ESM::ServiceCommand.last
      expect(command.command_name).to eq("broadcast")
      expect(command.arguments).to include(
        community_id: community.community_id,
        message: "Wipe at 8.",
        broadcast_to: server.server_id
      )
      expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    # The command is community-scoped, so the row has no server to point at and the arguments carry no server_id -
    # the same shape the Discord side sends, where broadcast takes broadcast_to and never server_id.
    it "mints a row with no server and no server_id argument" do
      allow_access(denied: false)

      post_broadcast

      command = ESM::ServiceCommand.last
      expect(command.server).to be_nil
      expect(command.community).to eq(community)
      expect(command.arguments).not_to have_key(:server_id)
    end

    it "passes the all-servers keyword straight through" do
      allow_access(denied: false)

      post_broadcast(broadcast_to: "all")

      expect(ESM::ServiceCommand.last.arguments).to include(broadcast_to: "all")
    end

    # The selector posts a public id, so a server from someone else's community must not resolve into a server_id the
    # command would then go looking for.
    it "refuses a server that belongs to another community" do
      allow_access(denied: false)
      outsider = create(:server, community: create(:community))

      expect { post_broadcast(broadcast_to: outsider.public_id) }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "dedupes a repeated submit to one row" do
      allow_access(denied: false)
      key = SecureRandom.uuid

      post_broadcast(idempotency_key: key)
      expect { post_broadcast(idempotency_key: key) }.not_to change(ESM::ServiceCommand, :count)

      expect(ESM::Service::API).to have_received(:call).once
    end

    it "renders the denial in the modal rather than dispatching" do
      allow_access(denied: true, reason: :not_allowlisted)

      expect { post_broadcast }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("You do not have permission to broadcast")
    end
  end

  describe "GET status" do
    let(:command) do
      ESM::ServiceCommand.create!(
        user:,
        community:,
        command_name: "broadcast",
        idempotency_key: SecureRandom.uuid,
        status: :completed,
        result: {recipients: 3}
      )
    end

    it "reports how many players were reached" do
      allow_access(denied: false)

      get "/communities/#{community.public_id}/broadcast/commands/#{command.public_id}/status",
        as: :turbo_stream

      expect(response.body).to include("Sent to 3 players")
    end

    it "is not found for another user's command" do
      allow_access(denied: false)
      command.update!(user: create(:user))

      get "/communities/#{community.public_id}/broadcast/commands/#{command.public_id}/status",
        as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end
end
