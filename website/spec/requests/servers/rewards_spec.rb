# frozen_string_literal: true

RSpec.describe "Servers::Rewards", type: :request do
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

  def post_reward(params = {})
    post "/servers/#{server.public_id}/reward",
      params: {idempotency_key: SecureRandom.uuid}.merge(params),
      as: :turbo_stream
  end

  describe "POST /reward" do
    it "dispatches a reward command naming the package being redeemed" do
      allow_access(denied: false)

      expect { post_reward(reward_id: "daily") }.to change(ESM::ServiceCommand, :count).by(1)

      command = ESM::ServiceCommand.last

      expect(command.command_name).to eq("reward")
      expect(command.arguments).to include(
        server_id: server.server_id,
        community_id: community.community_id,
        reward_id: "daily"
      )

      expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
      expect(response).to have_http_status(:ok)
    end

    # Finishing a claim names no package. There is nothing to name it with: the claim is the thing being delivered.
    it "names no package when a waiting claim is what is being delivered" do
      allow_access(denied: false)

      post_reward

      expect(ESM::ServiceCommand.last.arguments).not_to have_key(:reward_id)
    end

    # The form indexes its fields so the choices reach the command in the claim's own order, which is the only thing
    # pairing a choice with the vehicle it was made for.
    it "passes the player's per-vehicle choices in order" do
      allow_access(denied: false)

      post_reward(
        vehicles: {
          "1" => {spawn_location: "nearby", pin_code: "2222"},
          "0" => {spawn_location: "virtual_garage", territory_id: "a3f9k", pin_code: "1111"}
        }
      )

      expect(ESM::ServiceCommand.last.arguments[:vehicles]).to eq(
        [
          {spawn_location: "virtual_garage", territory_id: "a3f9k", pin_code: "1111"},
          {spawn_location: "nearby", pin_code: "2222"}
        ]
      )
    end

    # Everything else on a vehicle is the admin's configuration, and the command slices again on its own side
    it "drops anything the form had no business sending" do
      allow_access(denied: false)

      post_reward(vehicles: {"0" => {class_name: "Exile_Chopper_Hummingbird", pin_code: "1111"}})

      expect(ESM::ServiceCommand.last.arguments[:vehicles]).to eq([{pin_code: "1111"}])
    end

    # A POST never passes through the dashboard, so the page explaining the problem is not what stops this
    it "refuses outright when the server is too old to answer" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow_access(denied: false)
      server.update!(server_version: "2.0.4")

      expect { post_reward }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("older version of ESM")
    end

    it "rejects a denied claim with a 422 and never creates a command" do
      allow_access(denied: true, reason: :disabled)

      expect { post_reward }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::Service::API).not_to have_received(:call)
    end
  end

  describe "GET status" do
    it "serves the caller's own command by its public id" do
      command = create(:service_command, user:, server:, command_name: "reward")

      get "/servers/#{server.public_id}/reward/commands/#{command.public_id}/status", as: :turbo_stream

      expect(response).to have_http_status(:ok)
    end

    it "does not serve someone else's command" do
      command = create(:service_command, user: create(:user), server:, command_name: "reward")

      get "/servers/#{server.public_id}/reward/commands/#{command.public_id}/status", as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET territories" do
    def get_territories
      get "/servers/#{server.public_id}/reward/territories", params: {index: "0"}
    end

    it "offers the garages that still have room" do
      allow(ESM::Service::API).to receive(:call).with(:sync_command, any_args).and_return(
        [
          {id: "a3f9k", esm_custom_id: "base", territory_name: "Base", level: 3, vehicle_count: 2, garage_capacity: 8},
          {id: "b7c2m", esm_custom_id: nil, territory_name: "Outpost", level: 2, vehicle_count: 5, garage_capacity: 5}
        ]
      )

      get_territories

      expect(response.body).to include("base (6 of 8 free)")

      # Full, so it is left out rather than offered and then refused in game
      expect(response.body).not_to include("Outpost")
    end

    # A picker that cannot be filled is not a reason to fail the page. The player can still take a vehicle that
    # spawns next to them.
    it "says so plainly when the server cannot answer" do
      allow(ESM::Service::API).to receive(:call)
        .with(:sync_command, any_args)
        .and_raise(ESM::Service::API::Unreachable, "no responders")

      get_territories

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No territory with room in its garage")
    end
  end
end
