# frozen_string_literal: true

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
    allow(ESM::Service::API).to receive(:call).with(:async_command, any_args) do |_action, command_id:|
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

  it "404s an action on a server that doesn't exist" do
    expect {
      post "/servers/#{SecureRandom.uuid}/territories/#{territory_id}/pay",
        params: {idempotency_key: SecureRandom.uuid, dom_id: "region"},
        as: :turbo_stream
    }.not_to change(ESM::ServiceCommand, :count)

    expect(response).to have_http_status(:not_found)
  end

  describe "the command actions" do
    # route segment => [extra POST params, command_name, action-specific arguments]
    {
      "pay" => [{}, "pay", {}],
      "upgrade" => [{}, "upgrade", {}],
      "add_member" => [{target_uid:}, "add", {target: target_uid}],
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
        expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
        expect(response).to have_http_status(:ok)
      end
    end

    # add_member has its own denial example rather than leaning on pay's below, so a change to how it dispatches can't
    # leave it ungated without something failing.
    it "rejects a denied add_member with a 422 and never dispatches one" do
      allow_access(denied: true, reason: :not_allowlisted)

      expect { post_action("add_member", target_uid:) }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
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

  describe "GET index" do
    # The full page renders the shared servers/container shell, whose nav asks whether the server is connected and
    # whether the viewer manages it - NATS reads the command-action examples above never reach, since they respond
    # with a turbo_stream partial only.
    before do
      allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
      allow(ESM::Service::API).to receive(:call).with(:community_modifiable_by, any_args).and_return(false)
    end

    it "renders the territories shell" do
      get "/servers/#{server.public_id}/territories"

      expect(response).to have_http_status(:ok)
    end

    it "404s a viewer without server_territories access" do
      allow_access(denied: true, reason: :not_allowlisted)

      get "/servers/#{server.public_id}/territories"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET list" do
    before do
      allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
      allow(ESM::Service::API).to receive(:call).with(:sync_command, any_args).and_return(nil)
    end

    it "renders the territories list frame" do
      get "/servers/#{server.public_id}/territories/list"

      expect(response).to have_http_status(:ok)
    end

    it "404s a viewer without server_territories access" do
      allow_access(denied: true, reason: :not_allowlisted)

      get "/servers/#{server.public_id}/territories/list"

      expect(response).to have_http_status(:not_found)
    end

    context "with a territory marked for deletion" do
      let(:marked_row) do
        {
          id: "doomed",
          esm_custom_id: nil,
          name: "Doomed",
          level: 1,
          object_count: 3,
          radius: 25.0,
          flag_texture: "",
          flag_stolen: false,
          last_paid_at: nil,
          deleted_at: 1.day.ago.iso8601,
          owner_uid: "76561198000000099",
          owner_name: "Owner",
          moderators: [],
          build_rights: []
        }
      end

      let(:restore_path) { "/servers/#{server.public_id}/territories/doomed/restore" }

      before { allow(ESM::Service::API).to receive(:call).with(:sync_command, any_args).and_return([marked_row]) }

      it "offers a restore to a viewer who can run restore" do
        get "/servers/#{server.public_id}/territories/list"

        expect(response.body).to include(restore_path)
      end

      # Listing territories and restoring one are separate grants, so seeing the row is not the same as being offered
      # the button on it.
      it "leaves the restore off for a viewer who can list territories but not restore them" do
        allow(ESM::CommandAccess).to receive(:new) do |command_name:, **|
          verdict =
            if command_name.to_s == "restore"
              ESM::Command::Permission::Result.new(reason: :not_allowlisted, detail: nil)
            else
              ESM::Command::Permission::ALLOWED
            end

          instance_double(ESM::CommandAccess, verdict:)
        end

        get "/servers/#{server.public_id}/territories/list"

        expect(response.body).to include("Doomed")
        expect(response.body).not_to include(restore_path)
      end
    end
  end

  describe "GET show" do
    # territory_snapshot picks its read command from the real CommandAccess verdict for "info" (admin = any
    # territory, member = only their own) rather than from the file's blanket allow_access, which answers the same
    # verdict for every command name and so could never tell "info" apart from "territory". Everything other than
    # "info" stays allowed so the modal's own buttons render normally around the read being tested.
    def stub_info_access(allowed:)
      allow(ESM::CommandAccess).to receive(:new) do |command_name:, **|
        verdict =
          if command_name.to_s == "info" && !allowed
            ESM::Command::Permission::Result.new(reason: :not_allowlisted, detail: nil)
          else
            ESM::Command::Permission::ALLOWED
          end

        instance_double(ESM::CommandAccess, verdict:)
      end
    end

    # Records which command actually carried the read, so a context can prove it went through info or territory
    # specifically - a stub that answered every sync_command the same way could pass even if admin routed to the
    # wrong command name.
    attr_reader :requested_command_name

    def stub_territory_read(payload)
      allow(ESM::Service::API).to receive(:call) do |action, **options|
        next nil unless action == :sync_command

        @requested_command_name = options[:command_name].to_s
        payload
      end
    end

    let(:territory_payload) do
      {
        id: territory_id,
        esm_custom_id: nil,
        name: "Old Base",
        level: 1,
        object_count: 12,
        radius: 25.0,
        flag_texture: "",
        flag_stolen: false,
        last_paid_at: nil,
        deleted_at: nil,
        owner_uid: user.steam_uid,
        owner_name: "Owner",
        moderators: [],
        build_rights: []
      }
    end

    def get_show
      get "/servers/#{server.public_id}/territories/#{territory_id}"
    end

    it "reads any territory through info for an admin" do
      stub_info_access(allowed: true)
      stub_territory_read(territory_payload)

      get_show

      expect(requested_command_name).to eq("info")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('alt="Territory flag"')
    end

    it "reads only the caller's own territory through the member-scoped territory command" do
      stub_info_access(allowed: false)
      stub_territory_read(territory_payload)

      get_show

      expect(requested_command_name).to eq("territory")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('alt="Territory flag"')
    end

    it "offers the owner the controls that belong to an owner" do
      stub_info_access(allowed: false)
      stub_territory_read(territory_payload)

      get_show

      expect(response.body).to include(%(id="set_id_modal_#{territory_id}"))
      expect(response.body).to include(%(id="add_modal_#{territory_id}"))
    end

    # The controls follow the viewer's own stake in the territory, not how the territory was reached. info lets someone
    # read any territory, and reading it is all that grants.
    it "hides every action control from a viewer who reads the territory through info but holds no stake in it" do
      stub_info_access(allowed: true)
      stub_territory_read(territory_payload.merge(owner_uid: "76561198000000099"))

      get_show

      expect(response.body).to include('alt="Territory flag"')
      expect(response.body).not_to include(%(id="set_id_modal_#{territory_id}"))
      expect(response.body).not_to include(%(id="upgrade_modal_#{territory_id}"))
      expect(response.body).not_to include(%(id="add_modal_#{territory_id}"))
    end

    it "shows nothing and hides every action control for a non-member the territory command refuses" do
      stub_info_access(allowed: false)
      stub_territory_read(nil)

      get_show

      expect(requested_command_name).to eq("territory")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('alt="Territory flag"')
      expect(response.body).not_to include(%(id="pay_modal_#{territory_id}"))
      expect(response.body).not_to include(%(id="upgrade_modal_#{territory_id}"))
      expect(response.body).not_to include(%(id="set_id_modal_#{territory_id}"))
      expect(response.body).not_to include(%(id="add_modal_#{territory_id}"))
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
