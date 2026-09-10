# frozen_string_literal: true

RSpec.describe "Communities::RewardClaims", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:, ui_version: "2.1.0") }
  let(:user) { create(:user) }
  let(:player) { create(:user) }

  let(:max_attempts) { ESM::Command::Server::Reward::MAX_DELIVERY_ATTEMPTS }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(true)

    # The nav gates its entries on whether a command is reachable, which is a question only the bot can answer
    allow(ESM::CommandAccess).to receive(:new).and_return(
      instance_double(ESM::CommandAccess, verdict: ESM::Command::Permission::ALLOWED)
    )
  end

  def index_path
    "/communities/#{community.public_id}/reward_claims"
  end

  # Version gates are not enforced locally, the same as everywhere else on this site. A spec about what an older
  # server may do has to leave that bypass behind first.
  def enforce_versions!
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
  end

  def claim_path(claim, suffix = nil)
    base = "/communities/#{community.public_id}/servers/#{claim.server.public_id}" \
      "/reward_claims/#{claim.user.discord_id}"

    suffix ? "#{base}/#{suffix}" : base
  end

  def create_claim(claim_user: player, **attributes)
    ESM::ServerRewardClaim.create!(
      server_id: server.id,
      user_id: claim_user.id,
      reward_id: "vip",
      player_poptabs: 25_000,
      **attributes
    )
  end

  describe "GET /reward_claims" do
    it "lists what each player is still owed" do
      create_claim

      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(player.username)
      expect(response.body).to include(server.server_id)
      expect(response.body).to include("vip")
      expect(response.body).to include("Poptabs")
    end

    # Every bucket a claim can hold renders through the same badges the package list uses, and a claim's vehicles
    # carry delivery choices a package's never do.
    it "names each kind of thing a claim holds" do
      create_claim(
        items: {"Exile_Item_Can_Empty" => 3},
        vehicles: [{class_name: "Exile_Car_Hatchback", spawn_location: "virtual_garage"}]
      )

      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Poptabs")
      expect(response.body).to include("Item")
      expect(response.body).to include("Vehicle")
    end

    it "explains itself rather than showing an empty table" do
      get index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No rewards waiting")
      expect(response.body).not_to include("Any player")
    end

    it "names what stopped a stuck claim" do
      create_claim(
        state: :failed,
        attempt_count: max_attempts,
        state_details: {failures: [{bucket: "vehicles", name: "Hatchback", reason: "No room to spawn here"}]}
      )

      get index_path

      expect(response.body).to include("Stuck")
      expect(response.body).to include("Hatchback: No room to spawn here")
      expect(response.body).to include("#{max_attempts} of #{max_attempts} attempts")
    end

    # Nothing is blocked by an unfinished delivery, so the row saying one is running is the only thing wrong with it.
    it "stops calling a long unfinished delivery a delivery" do
      create_claim(state: :in_flight, updated_at: 10.minutes.ago)

      get index_path

      expect(response.body).to include("Interrupted")
      expect(response.body).to include("did not finish")
      expect(response.body).not_to include("Allow retry")
    end

    # A claim only ever comes from the v2 command, so a community running nothing but v1 has a page that could never
    # hold a row. The card and the nav entry go with it.
    it "is not offered to a community with nothing but v1 servers" do
      server.update!(ui_version: "1.0.0")

      get "/communities/#{community.public_id}"

      expect(response.body).not_to include("View reward claims")
    end

    it "belongs to whoever can change the community" do
      allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(false)

      get index_path

      expect(response).to have_http_status(:not_found)
    end

    it "leaves other communities' claims where they are" do
      other_server = create(:server, community: create(:community), ui_version: "2.1.0")
      ESM::ServerRewardClaim.create!(server_id: other_server.id, user_id: player.id, player_poptabs: 10)

      get index_path

      expect(response.body).to include("No rewards waiting")
    end
  end

  describe "GET /reward_claims/new" do
    it "opens an empty grant" do
      server

      get "#{index_path}/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Add rewards")
      expect(response.body).to include("reward_claim[items][][classname]")
      expect(response.body).to include(server.server_id)
    end

    it "names a server that could not take a vehicle" do
      enforce_versions!
      server.update!(server_version: "2.0.4")

      get "#{index_path}/new"

      expect(response.body).to include("cannot hand out vehicles yet")
    end
  end

  describe "POST /reward_claims" do
    let(:registered_player) { create(:user) }

    before do
      allow(Bot).to receive(:send_message)

      # The player has to be somebody the game server knows before anything is written for them
      allow(ESM::Service::API).to receive(:call).with(:sync_command, anything).and_return({locker: 0})
    end

    def grant_params(**overrides)
      {
        reward_claim: {
          server_id: server.public_id,
          player: registered_player.steam_uid,
          player_poptabs: "5000",
          locker_poptabs: "0",
          respect: "0"
        }.merge(overrides)
      }
    end

    it "hands a player something they never redeemed" do
      post index_path, params: grant_params

      claim = ESM::ServerRewardClaim.sole
      expect(claim.user_id).to eq(registered_player.id)
      expect(claim.player_poptabs).to eq(5_000)

      # Nothing was redeemed, so finishing this puts no package on cooldown
      expect(claim.reward_id).to be_nil
    end

    it "tells the player it is waiting for them" do
      post index_path, params: grant_params

      expect(Bot).to have_received(:send_message).with(
        channel_id: registered_player.discord_id,
        message: hash_including(title: "A reward is waiting for you")
      )
    end

    # The grant still happened, so the page says so rather than pretending the whole thing failed
    it "still grants when the bot cannot be reached" do
      allow(Bot).to receive(:send_message).and_raise(ESM::Service::API::Unreachable, "no responders")

      post index_path, params: grant_params

      expect(ESM::ServerRewardClaim.count).to eq(1)
      expect(response.body).to include("could not be messaged about it")
    end

    # The one claim per player cap exists so a player cannot stockpile their own redemptions. An admin handing out a
    # prize is not what it was written against, so a grant merges instead of being refused.
    it "adds to what the player is already owed" do
      ESM::ServerRewardClaim.create!(
        server_id: server.id, user_id: registered_player.id, reward_id: "vip",
        player_poptabs: 1_000, items: {"Exile_Item_Can_Empty" => 2}
      )

      post index_path, params: grant_params(items: [{classname: "Exile_Item_Can_Empty", quantity: "3"}])

      claim = ESM::ServerRewardClaim.sole
      expect(claim.player_poptabs).to eq(6_000)
      expect(claim.items).to eq({Exile_Item_Can_Empty: 5})

      # The package it came from still owns the cooldown, whatever an admin has added on top
      expect(claim.reward_id).to eq("vip")
    end

    it "puts a stopped claim back within reach when it grants onto one" do
      ESM::ServerRewardClaim.create!(
        server_id: server.id, user_id: registered_player.id, player_poptabs: 1_000,
        state: :failed, attempt_count: max_attempts,
        state_details: {failures: [
          {bucket: "vehicles", name: "Hatchback", reason: "No room to spawn here"},
          {bucket: "items", name: "Can", reason: "Not in this server's config"}
        ]}
      )

      post index_path, params: grant_params(
        vehicles: [{class_name: "Exile_Car_Hatchback", spawn_location: "nearby"}]
      )

      claim = ESM::ServerRewardClaim.sole
      expect(claim).to be_waiting
      expect(claim.attempt_count).to eq(0)

      # The vehicle reason described a different set of vehicles the moment another one was added. The item one
      # is still accurate and stays.
      expect(claim.state_details[:failures].map { |failure| failure[:bucket] }).to eq(["items"])
    end

    it "refuses a reward that holds nothing" do
      post index_path, params: grant_params(player_poptabs: "0")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("A reward has to hold something")
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    it "asks for an identifier when nothing was typed" do
      post index_path, params: grant_params(player: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter the player's Steam UID or Discord ID")
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    # Otherwise this form answers "does an ESM account exist for this Steam UID", which is a question nobody who can
    # open it has any business asking about a player with no connection to their community.
    it "answers the same way however the lookup came up empty" do
      allow(ESM::Service::API).to receive(:call).with(:sync_command, anything).and_return(nil)

      inputs = [
        "Dave",                                      # not an identifier at all
        "76561199999999999",                         # a Steam UID nothing here knows
        create(:user, steam_uid: nil).discord_id,    # a Discord account that never registered
        registered_player.steam_uid                  # a real ESM account that has never played here
      ]

      messages = inputs.map do |player|
        post index_path, params: grant_params(player:)

        response.body[/We couldn't find that player on \w+\./]
      end

      expect(messages.uniq.size).to eq(1)
      expect(messages.first).to be_present
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    # The whole point of asking the server: a valid Steam UID belonging to somebody who has never played here must
    # not resolve to the Discord account behind it.
    it "will not grant to a player the server has never seen" do
      allow(ESM::Service::API).to receive(:call).with(:sync_command, anything).and_return(nil)

      post index_path, params: grant_params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("We couldn't find that player")
      expect(response.body).not_to include(registered_player.username)
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    # info raises rather than returning nothing when it has no player to describe, so the command answering at all is
    # the answer. Reading that as a transport failure told owners their connected server was offline.
    it "reads a refusal from the command as a player it does not know" do
      allow(ESM::Service::API).to receive(:call)
        .with(:sync_command, anything)
        .and_raise(ESM::Service::API::RemoteError.new(:internal_error, "no player information"))

      post index_path, params: grant_params

      expect(response.body).to include("We couldn't find that player")
      expect(response.body).not_to include("is offline")
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    it "says so when the server could not be asked" do
      allow(ESM::Service::API).to receive(:call)
        .with(:sync_command, anything)
        .and_raise(ESM::Service::API::Unreachable, "no responders")

      post index_path, params: grant_params

      expect(response.body).to include("is offline")
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    it "does not grant onto a server belonging to someone else" do
      other_server = create(:server, community: create(:community), ui_version: "2.1.0")

      post index_path, params: grant_params(server_id: other_server.public_id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end

    # Vehicles need SQF that shipped with the newer extension, and the picker cannot gate itself on a server the
    # same form is still choosing.
    it "refuses vehicles on a server too old to spawn them" do
      enforce_versions!
      server.update!(server_version: "2.0.4")

      post index_path, params: grant_params(
        vehicles: [{class_name: "Exile_Car_Hatchback", spawn_location: "nearby"}]
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(ESM::ServerRewardClaim.count).to eq(0)
    end
  end

  describe "PATCH /reward_claims/:user_id/release" do
    it "gives a stopped claim back its attempts" do
      claim = create_claim(state: :failed, attempt_count: max_attempts)

      patch claim_path(claim, "release")

      expect(response).to have_http_status(:ok)
      expect(claim.reload).to be_waiting
      expect(claim.attempt_count).to eq(0)
    end

    # The reward command finds a claim whatever state it is in and only guards on failed, so every other state is
    # already deliverable and there is nothing here to allow.
    it "leaves a delivery that never reported back alone" do
      claim = create_claim(state: :in_flight, attempt_count: 2)

      patch claim_path(claim, "release")

      expect(response.body).to include("can already be delivered")
      expect(claim.reload).to be_in_flight
      expect(claim.attempt_count).to eq(2)
    end

    it "says so when there was nothing to allow" do
      claim = create_claim(state: :waiting)

      patch claim_path(claim, "release")

      expect(response.body).to include("can already be delivered")
      expect(claim.reload).to be_waiting
    end

    it "does not reach a claim on another community's server" do
      other_server = create(:server, community: create(:community), ui_version: "2.1.0")
      claim = ESM::ServerRewardClaim.create!(
        server_id: other_server.id, user_id: player.id, player_poptabs: 10, state: :failed
      )

      patch "/communities/#{community.public_id}/servers/#{other_server.public_id}" \
        "/reward_claims/#{player.discord_id}/release"

      expect(response).to have_http_status(:not_found)
      expect(claim.reload).to be_failed
    end
  end

  describe "GET /reward_claims/:user_id/edit" do
    it "opens on what the player is owed right now" do
      claim = create_claim(items: {"Exile_Item_Can_Empty" => 3})

      get claim_path(claim, "edit")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Update claim")
      expect(response.body).to include("Exile_Item_Can_Empty")
      expect(response.body).to include(">25000<").or include('value="25000"')
    end

    # The URL is what names the claim, so an edit has no use for the two fields that would choose a different one
    it "does not offer to move the claim to somebody else" do
      claim = create_claim

      get claim_path(claim, "edit")

      expect(response.body).not_to include("reward_claim[player]")
      expect(response.body).not_to include("reward_claim[server_id]")
    end
  end

  describe "PATCH /reward_claims/:user_id" do
    it "replaces what the claim holds rather than adding to it" do
      claim = create_claim(items: {"Exile_Item_Can_Empty" => 3})

      patch claim_path(claim), params: {
        reward_claim: {player_poptabs: "100", locker_poptabs: "0", respect: "0"}
      }

      claim.reload
      expect(claim.player_poptabs).to eq(100)
      expect(claim.items).to eq({})
    end

    # Taking the vehicle out is the fix for a claim stuck on one that cannot spawn, so the reason it collected goes
    # with it. An untouched bucket keeps a reason that is still true.
    it "drops the reasons for whatever it changed and keeps the rest" do
      claim = create_claim(
        items: {"Exile_Item_Can_Empty" => 3},
        vehicles: [{class_name: "Exile_Car_Hatchback", spawn_location: "nearby"}],
        state: :failed, attempt_count: max_attempts,
        state_details: {failures: [
          {bucket: "vehicles", name: "Hatchback", reason: "No room to spawn here"},
          {bucket: "items", name: "Can", reason: "Not in this server's config"}
        ]}
      )

      patch claim_path(claim), params: {
        reward_claim: {
          player_poptabs: "0", locker_poptabs: "0", respect: "0",
          items: [{classname: "Exile_Item_Can_Empty", quantity: "3"}]
        }
      }

      claim.reload
      expect(claim.vehicles).to eq([])
      expect(claim.state_details[:failures].map { |failure| failure[:bucket] }).to eq(["items"])

      # An admin has just said what this claim holds, so it is one they mean the player to receive
      expect(claim).to be_waiting
      expect(claim.attempt_count).to eq(0)
    end

    # A delivery in progress is a delivery of what the claim held a moment ago, so a row still calling itself one
    # is describing something that is not happening.
    it "stops a rewritten claim calling itself a delivery in progress" do
      claim = create_claim(state: :in_flight, attempt_count: 2)

      patch claim_path(claim), params: {
        reward_claim: {player_poptabs: "100", locker_poptabs: "0", respect: "0"}
      }

      claim.reload
      expect(claim).to be_waiting

      # Those attempts were spent by deliveries that really did finish, so they stay spent
      expect(claim.attempt_count).to eq(2)
    end

    it "refuses to empty a claim rather than leaving one nobody can deliver" do
      claim = create_claim

      patch claim_path(claim), params: {
        reward_claim: {player_poptabs: "0", locker_poptabs: "0", respect: "0"}
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("A reward has to hold something")
      expect(claim.reload.player_poptabs).to eq(25_000)
    end
  end

  describe "GET /reward_claims/:user_id/confirm_destroy" do
    it "itemizes what deleting the claim takes away" do
      claim = create_claim(items: {"Exile_Item_Can_Empty" => 3})

      get claim_path(claim, "confirm_destroy")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("will not receive any of this")
      expect(response.body).to include("25,000")
    end

    # A claim with no code was never redeemed from anything, so there is no package waiting to be taken again.
    it "does not promise a second helping of a claim an admin built" do
      claim = create_claim(reward_id: nil)

      get claim_path(claim, "confirm_destroy")

      expect(response.body).to include("An admin put this claim together by hand")
    end

    it "offers the gentler option only when there is one" do
      stopped = create_claim(state: :failed, attempt_count: max_attempts)

      get claim_path(stopped, "confirm_destroy")

      expect(response.body).to include("Allow a retry instead")
    end

    it "does not offer a retry for a claim that is already deliverable" do
      claim = create_claim(state: :waiting)

      get claim_path(claim, "confirm_destroy")

      expect(response.body).not_to include("Allow a retry instead")
    end
  end

  describe "DELETE /reward_claims/:user_id" do
    it "takes the claim off the board" do
      claim = create_claim(state: :failed)

      delete claim_path(claim)

      expect(response).to have_http_status(:ok)
      expect(ESM::ServerRewardClaim.find_by(id: claim.id)).to be_nil
    end

    it "does not reach a claim belonging to a player without one" do
      create_claim

      delete "/communities/#{community.public_id}/servers/#{server.public_id}" \
        "/reward_claims/#{user.discord_id}"

      expect(response).to have_http_status(:not_found)
      expect(ESM::ServerRewardClaim.count).to eq(1)
    end
  end
end
