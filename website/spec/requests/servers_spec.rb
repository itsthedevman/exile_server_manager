# frozen_string_literal: true

RSpec.describe "Servers", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  # Whether the viewer can manage the server decides how much the page explains, so it's stated per example rather than
  # left to whatever the bot would say about this user's Discord roles.
  let(:manageable) { false }

  before do
    sign_in user
    allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(manageable)
  end

  describe "GET show" do
    # Allowing exactly one command leaves the hub rendering exactly what that command puts on it. Allowing everything
    # would drag every other card's game-server reads into these examples for no benefit.
    def allow_only(allowed)
      allow(ESM::CommandAccess).to receive(:new) do |command_name:, **|
        verdict =
          if command_name.to_s == allowed
            ESM::Command::Permission::ALLOWED
          else
            ESM::Command::Permission::Result.new(reason: :not_allowlisted, detail: nil)
          end

        instance_double(ESM::CommandAccess, verdict:)
      end
    end

    it "offers the lookup bar to an admin who can view a player" do
      allow_only("info")

      get "/servers/#{server.public_id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Admin tools")
      expect(response.body).to include(%(action="/servers/#{server.public_id}/players/lookup"))

      # The field name is the whole contract between this bar and the resolver, and a wrong one would fail silently
      # as an empty query rather than as an error.
      expect(response.body).to include(%(name="q"))
    end

    it "keeps the admin section off the page entirely for a player" do
      allow_only("me")

      get "/servers/#{server.public_id}"

      expect(response.body).not_to include("Admin tools")
      expect(response.body).not_to include("players/lookup")
    end

    context "when the player can be rewarded" do
      before do
        allow_only("reward")

        server.server_rewards.default.first.update!(name: "Daily Drop", player_poptabs: 5_000, respect: 100)
      end

      it "shows the default package" do
        get "/servers/#{server.public_id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Daily Drop")
        expect(response.body).to include("5,000 poptabs · 100 respect")
      end

      # Only the default is ever on the page. Naming the others would put every coupon an owner runs in plain sight,
      # and nothing else stops a player claiming a package the moment they can see its ID.
      it "keeps every other package off the page" do
        ESM::ServerReward.create!(server_id: server.id, reward_id: "secret_sauce", player_poptabs: 100)

        get "/servers/#{server.public_id}"

        expect(response.body).not_to include("secret_sauce")
        expect(response.body).to include("Been given a reward code?")
      end

      # Rewards are handed over in game, so a package cannot be taken while the server is down. Saying so beats a
      # button whose only outcome is a refusal.
      it "offers no way to take one while the server is down" do
        get "/servers/#{server.public_id}"

        expect(response.body).to include("Server offline")
        expect(response.body).not_to include("Redeem")
      end

      context "and the server is up" do
        before { allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true) }

        it "offers to redeem the package" do
          get "/servers/#{server.public_id}"

          expect(response.body).to include("Redeem")
          expect(response.body).to include(%(action="/servers/#{server.public_id}/reward"))
        end

        # The way any package other than the default is taken. Owners hand the ID out however they like, which is what
        # makes a coupon possible.
        it "takes a typed code for anything else" do
          get "/servers/#{server.public_id}"

          expect(response.body).to include(%(name="reward_id"))
          expect(response.body).to include("Reward code")
        end

        it "counts down instead while the package's cooldown runs" do
          create(
            :cooldown, :active,
            command_name: "reward",
            scope_key: "default",
            steam_uid: user.steam_uid,
            community_id: community.id,
            server_id: server.id
          )

          get "/servers/#{server.public_id}"

          expect(response.body).to include("Available in")

          # The code box below it still offers a Redeem of its own, so what has to be gone is the default's own
          # form, which is the only thing carrying the package's ID
          expect(response.body).not_to include(%(value="default"))
        end
      end

      # The cap is one claim per player per server, so a package cannot be taken until the last one is finished. The
      # page has to say why rather than leaving a button that would be refused.
      it "shows what is still owed and closes the packages until it is finished" do
        ESM::ServerRewardClaim.create!(server_id: server.id, user_id: user.id, player_poptabs: 25)

        get "/servers/#{server.public_id}"

        expect(response.body).to include("Rewards waiting for you")
        expect(response.body).to include("Finish your claim first")
      end

      it "names what stopped the last attempt" do
        ESM::ServerRewardClaim.create!(
          server_id: server.id,
          user_id: user.id,
          player_poptabs: 25,
          state: :failed,
          state_details: {failures: [{bucket: "vehicles", name: "Hatchback", reason: "No room to spawn here"}]}
        )

        get "/servers/#{server.public_id}"

        expect(response.body).to include("Hatchback: No room to spawn here")
        expect(response.body).to include("Needs an admin")
      end
    end
  end

  describe "GET live" do
    let(:info) do
      ESM::Steam::ServerQuery::Info.new(
        protocol: 17, name: "exilemod.com", map: "tanoa", folder: "Arma3", game: "exile",
        app_id: 0, players: 12, max_players: 100, bots: 0, version: "2.20.152984"
      )
    end

    it "renders what the server reported" do
      allow(ESM::Steam::ServerQuery).to receive(:info).and_return(info)

      get "/servers/#{server.public_id}/live"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("tanoa", "12/100")
    end

    # The Arma build only matters when someone can't connect, which is rare enough that it doesn't earn a permanent
    # line in a rail that renders on every page of the hub.
    it "leaves the game version out" do
      allow(ESM::Steam::ServerQuery).to receive(:info).and_return(info)

      get "/servers/#{server.public_id}/live"

      expect(response.body).not_to include("2.20.152984")
    end

    it "asks the query port, which is one past the port players connect on" do
      allow(ESM::Steam::ServerQuery).to receive(:info).and_return(info)

      get "/servers/#{server.public_id}/live"

      expect(ESM::Steam::ServerQuery).to have_received(:info)
        .with(host: server.server_ip, port: server.server_port.to_i + 1)
    end

    context "when the server can't be reached" do
      before do
        allow(ESM::Steam::ServerQuery).to receive(:info)
          .and_raise(ESM::Steam::ServerQuery::Timeout, "did not answer")
      end

      # The whole reason this is its own lazy request. A server that's down, firewalled, or simply not answering must
      # cost this frame and nothing else.
      it "renders an empty frame rather than failing" do
        get "/servers/#{server.public_id}/live"

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Players")
      end

      # A player can't fix an address they don't own, so the panel just stays empty for them.
      it "says nothing to a player, even on a server that is up" do
        allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)

        get "/servers/#{server.public_id}/live"

        expect(response.body).not_to include("No answer")
      end

      context "and the viewer manages the server" do
        let(:manageable) { true }

        # A server ESM is already talking to that still won't answer a query has usually been given the wrong address
        # here, so the message names what was dialed rather than restating that something failed.
        it "names the address it dialed when the server is up and still silent" do
          allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)

          get "/servers/#{server.public_id}/live"

          expect(response.body).to include("<code class=\"text-warning-emphasis\">#{server.server_ip}:#{server.query_port}</code>")
        end

        # The ip is free text on the server form, so it can't be trusted into a template.
        it "escapes an address rather than rendering it as markup" do
          allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)
          server.update!(server_ip: "<script>alert(1)</script>")

          get "/servers/#{server.public_id}/live"

          expect(response.body).to include("&lt;script&gt;")
          expect(response.body).not_to include("<script>alert(1)</script>")
        end

        # The status line directly above already says Offline. Repeating it under a heading the owner can't act on is
        # noise, not an explanation.
        it "stays quiet when the server is simply down" do
          get "/servers/#{server.public_id}/live"

          expect(response.body).not_to include("No answer")
        end
      end
    end

    it "does not leak an unexpected reply as a 500" do
      allow(ESM::Steam::ServerQuery).to receive(:info)
        .and_raise(ESM::Steam::ServerQuery::UnexpectedResponse, "reply was split")

      get "/servers/#{server.public_id}/live"

      expect(response).to have_http_status(:ok)
    end

    it "404s for a server that doesn't exist" do
      get "/servers/#{SecureRandom.uuid}/live"

      expect(response).to have_http_status(:not_found)
    end

    it "requires a signed-in user" do
      sign_out user

      get "/servers/#{server.public_id}/live"

      expect(response).to redirect_to("/login")
    end
  end
end
