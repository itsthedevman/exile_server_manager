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
    allow(ESM::Service::API).to receive(:call).with(:sync_command, any_args).and_return(nil)
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

  describe "GET list" do
    before { allow_access(denied: false) }

    # The arguments handed to the players command are the whole contract between this page and the game server, so
    # they are what these assert on rather than the rendered markup.
    def command_arguments
      captured = nil

      allow(ESM::Service::API).to receive(:call) do |handler, **options|
        captured = options[:arguments] if handler == :sync_command
        nil
      end

      yield

      captured
    end

    it "asks for the look-back window when no name is given" do
      arguments = command_arguments { get "/servers/#{server.public_id}/players/list?window=7d" }

      expect(arguments).to include(:connected_since)
      expect(arguments).not_to have_key(:name)
    end

    it "passes a name through to the query" do
      arguments = command_arguments { get "/servers/#{server.public_id}/players/list?name=Dave" }

      expect(arguments[:name]).to eq("Dave")
    end

    # A blank name would match every account, so it has to read as "no name given" rather than as a search.
    it "treats a blank name as absent" do
      arguments = command_arguments { get "/servers/#{server.public_id}/players/list?name=%20%20" }

      expect(arguments).not_to have_key(:name)
    end

    it "caps a name at the width of the column it searches" do
      arguments = command_arguments { get "/servers/#{server.public_id}/players/list?name=#{"a" * 100}" }

      expect(arguments[:name].length).to eq(64)
    end

    # The specs above all run with players: nil, which renders the "can't reach the server" state and skips the table
    # entirely. These hand the page a real row so the name-mode markup is actually exercised.
    context "with players to show" do
      let(:player_row) do
        {
          uid: "76561198000000001",
          name: "Dave",
          locker: 0,
          score: 10,
          kills: 1,
          deaths: 1,
          first_connect_at: 2.days.ago.iso8601,
          last_connect_at: 1.hour.ago.iso8601,
          last_disconnect_at: nil,
          total_connections: 3,
          money: 100,
          damage: 0.0,
          online: true
        }
      end

      before { allow(ESM::Service::API).to receive(:call).and_return([player_row]) }

      it "names what it is matching and offers a way back" do
        get "/servers/#{server.public_id}/players/list?name=Dave"

        expect(response.body).to include('Matching "Dave"')
        expect(response.body).to include("Clear")
      end

      # The searched-for name is drawn straight into the header, so it is user input rendered as markup.
      it "escapes the name it echoes back" do
        get "/servers/#{server.public_id}/players/list?name=#{CGI.escape("<script>x</script>")}"

        expect(response.body).not_to include("<script>x</script>")
        expect(response.body).to include("&lt;script&gt;")
      end

      # Without this the client-side box's "no matches" is indistinguishable from "never played here".
      it "offers to search past the window when not already searching" do
        get "/servers/#{server.public_id}/players/list?window=7d"

        expect(response.body).to include("Search every player on")
        expect(response.body).to include("players-table-search-url-value")
      end

      it "drops the escalation once the search has already reached past the window" do
        get "/servers/#{server.public_id}/players/list?name=Dave"

        expect(response.body).not_to include("Search every player on")
      end
    end

    # A name search and the recency listing answer different questions. Sharing a cache entry would let whichever ran
    # first serve the other for the rest of the TTL.
    it "does not serve a name search from the listing's cache" do
      calls = 0

      allow(ESM::Service::API).to receive(:call) do |handler, **|
        calls += 1 if handler == :sync_command
        nil
      end

      get "/servers/#{server.public_id}/players/list?window=7d"
      get "/servers/#{server.public_id}/players/list?name=Dave"

      expect(calls).to eq(2)
    end
  end

  describe "GET show" do
    before { allow_access(denied: false) }

    # The page asks two different questions of two different systems: who is this (whois) and what is their character
    # here (info). Routing the stub by command name is what lets one answer while the other doesn't.
    def stub_commands(whois:, info: nil)
      allow(ESM::Service::API).to receive(:call) do |handler, **options|
        next nil unless handler == :sync_command

        (options[:command_name].to_s == "whois") ? whois : info
      end
    end

    let(:target_uid) { "76561198000000001" }

    let(:steam_identity) do
      {
        username: "Dave",
        avatar: nil,
        profile_url: "https://steamcommunity.com/id/dave",
        profile_visibility: "Public",
        profile_created_at: 5.years.ago.iso8601,
        community_banned: false,
        vac_banned: false,
        number_of_vac_bans: 0,
        days_since_last_ban: 0
      }
    end

    # The whole point of the page: a UID with no character here still gets a real answer rather than a dead end.
    it "renders identity even when the player has never connected" do
      stub_commands(whois: {steam: steam_identity, has_account: false, registered: false}, info: nil)

      get "/servers/#{server.public_id}/players/#{target_uid}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dave")
      expect(response.body).to include("No ESM account")
    end

    # Three different findings that used to render as the same shrug.
    it "distinguishes a registered non-member from someone with no account" do
      stub_commands(whois: {steam: steam_identity, has_account: true, registered: true}, info: nil)

      get "/servers/#{server.public_id}/players/#{target_uid}"

      expect(response.body).to include("not a member of")
      expect(response.body).not_to include("No ESM account")
    end

    it "shows the Discord identity when whois hands one over" do
      discord = {
        id: "987654321098765432",
        username: "dave_on_discord",
        avatar_url: nil,
        distinct: "dave#0",
        status: nil,
        creation_time: 3.years.ago.iso8601
      }
      stub_commands(whois: {steam: steam_identity, has_account: true, registered: true, discord:}, info: nil)

      get "/servers/#{server.public_id}/players/#{target_uid}"

      expect(response.body).to include("dave_on_discord", "987654321098765432")
      expect(response.body).not_to include("not a member of")
    end

    # Reachable by Discord ID rather than by UID, so this page can't produce it today. The branch exists so the
    # resolver has somewhere to land rather than falling through to "no ESM account", which would be wrong.
    it "separates an unlinked account from one with no account at all" do
      stub_commands(whois: {steam: steam_identity, has_account: true, registered: false}, info: nil)

      get "/servers/#{server.public_id}/players/#{target_uid}"

      expect(response.body).to include("never linked a Steam account")
      expect(response.body).not_to include("No ESM account")
    end

    # Losing the identity lookup must not cost the admin the character data they came for.
    it "still renders when the identity lookup fails" do
      allow(ESM::Service::API).to receive(:call) do |handler, **options|
        next nil unless handler == :sync_command
        raise ESM::Service::API::Unreachable if options[:command_name].to_s == "whois"

        nil
      end

      get "/servers/#{server.public_id}/players/#{target_uid}"

      expect(response).to have_http_status(:ok)
    end

    # Whether Discord comes back depends on the caller's community, so one community's answer must never be handed to
    # another's admin out of the cache.
    it "keys the identity cache per community" do
      other_server = create(:server, community: create(:community))
      seen = []

      allow(ESM::Service::API).to receive(:call) do |handler, **options|
        next nil unless handler == :sync_command && options[:command_name].to_s == "whois"

        seen << options[:community_id]
        {steam: steam_identity, has_account: false, registered: false}
      end

      get "/servers/#{server.public_id}/players/#{target_uid}"
      get "/servers/#{other_server.public_id}/players/#{target_uid}"

      expect(seen.uniq.length).to eq(2)
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
