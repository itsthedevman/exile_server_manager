# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Servers::Territories", type: :request do
  # A describe-body local (not a let) so it's in scope where the table is built.
  target_uid = "76561198000000042"

  # The current territory id rides in the URL; the controller reads it back from
  # the doubled route param (`:territory_territory_id`).
  let(:territory_id) { "oldbase" }

  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before do
    sign_in user

    # Authorized by default; the rejection example overrides. The real verdict resolves registration + the community's
    # enable/allowlist config + server connectivity - stubbed here so these specs exercise the dispatch path, not access.
    allow_access(denied: false)

    # Boundary stubs. The real call is a blocking NATS request/reply whose bot-side
    # handler marks the row non-pending; mirror that so idempotency behaves as it
    # does in production. Poll is skipped so specs don't wait on a settle.
    allow(ESM::Service::API).to receive(:call) do |_action, command_id:|
      ESM::ServiceCommand.find(command_id).dispatched!
    end
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

  def post_action(segment, **params)
    post "/servers/#{server.public_id}/territories/#{territory_id}/#{segment}",
      params: {idempotency_key: SecureRandom.uuid, dom_id: "region"}.merge(params),
      as: :turbo_stream
  end

  describe "the command actions" do
    # route segment => [extra POST params, command_name, action-specific arguments]
    {
      "pay" => [{}, "pay", {}],
      "upgrade" => [{}, "upgrade", {}],
      "promote_member" => [{target_uid:}, "promote", {target: target_uid}],
      "demote_member" => [{target_uid:}, "demote", {target: target_uid}],
      "remove_member" => [{target_uid:}, "remove", {target: target_uid}],
      "set_id" => [{custom_id: "newbase"}, "set_id", {old_territory_id: "oldbase", new_territory_id: "newbase"}]
    }.each do |segment, (params, command_name, action_args)|
      it "POST /#{segment} builds and dispatches a #{command_name} command" do
        expect { post_action(segment, **params) }.to change(ESM::ServiceCommand, :count).by(1)

        command = ESM::ServiceCommand.last
        expect(command.command_name).to eq(command_name)
        expect(command.arguments).to include(
          server_id: server.server_id,
          community_id: community.community_id,
          territory_id:,
          **action_args
        )
        expect(ESM::Service::API).to have_received(:call).with(:service_command, command_id: command.id)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "the shared command flow" do
    it "dedupes on idempotency_key so a double-submit dispatches once" do
      key = SecureRandom.uuid

      expect do
        post_action("pay", idempotency_key: key)
        post_action("pay", idempotency_key: key)
      end.to change(ESM::ServiceCommand, :count).by(1)

      expect(ESM::Service::API).to have_received(:call).once
    end

    it "does not re-dispatch when a same-key retry finds the command still pending" do
      # The default stub flips the row out of pending as it dispatches, which hides the race. Leave it pending so the
      # retry sees an in-flight command - only the request that created the row may fire the work.
      allow(ESM::Service::API).to receive(:call)
      key = SecureRandom.uuid

      post_action("pay", idempotency_key: key)
      post_action("pay", idempotency_key: key)

      expect(ESM::Service::API).to have_received(:call).once
    end

    it "requires a signed-in user" do
      sign_out user
      post_action("pay")

      expect(response).to redirect_to("/login")
    end

    it "rejects a denied command with a 422 and never dispatches one" do
      allow_access(denied: true, reason: :disabled)

      expect { post_action("pay") }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
    end
  end

  describe "GET status" do
    def get_status(public_id)
      get "/servers/#{server.public_id}/territories/commands/#{public_id}/status", as: :turbo_stream
    end

    it "serves the caller's own command by its public id" do
      command = create(:service_command, user:, server:)
      get_status(command.public_id)

      expect(response).to have_http_status(:ok)
    end

    it "404s a command that belongs to another user" do
      other = create(:service_command, server:, user: create(:user))
      get_status(other.public_id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
