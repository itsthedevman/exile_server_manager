# frozen_string_literal: true

RSpec.describe "Communities::Cooldowns", type: :request do
  let(:community) { create(:community) }
  let!(:server) { create(:server, community:) }
  # The factory derives server_id from the community, so a second server in the same one needs its own.
  let(:other_server) { create(:server, community:, server_id: "#{community.community_id}_second") }
  let(:user) { create(:user) }
  let(:player) { create(:user) }

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

  def create_cooldown(command_name: "me", target: server, expires_at: 5.minutes.from_now, **owner)
    create(
      :cooldown,
      community_id: community.id,
      server_id: target&.id,
      command_name:,
      expires_at:,
      cooldown_type: "minutes",
      cooldown_quantity: 5,
      **owner
    )
  end

  def get_index(**filters)
    get "/communities/#{community.public_id}/cooldowns", params: filters
  end

  def table_rows
    Nokogiri::HTML(response.body).css("tbody tr")
  end

  def filter_form
    Nokogiri::HTML(response.body).css("form[data-controller='cooldown-filters']").first
  end

  def post_clear(idempotency_key: SecureRandom.uuid, **filters)
    post "/communities/#{community.public_id}/cooldowns/clear",
      params: filters.merge(idempotency_key:, dom_id: "cooldown_result"),
      as: :turbo_stream
  end

  describe "GET /cooldowns" do
    it "lists the running cooldowns and leaves the expired ones out" do
      allow_access(denied: false)
      create_cooldown(steam_uid: player.steam_uid)
      create_cooldown(steam_uid: player.steam_uid, command_name: "gamble", expires_at: 5.minutes.ago)

      get_index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("me")
      expect(response.body).not_to include("gamble")
    end

    # The reason the page needs its own empty state rather than reading as broken: with the two-second default,
    # nothing running is the normal condition.
    it "explains an empty table rather than just showing nothing" do
      allow_access(denied: false)

      get_index

      expect(response.body).to include("Nobody is on cooldown")
    end

    it "includes inactive rows only when asked" do
      allow_access(denied: false)
      create_cooldown(steam_uid: player.steam_uid, command_name: "gamble", expires_at: 5.minutes.ago)

      get_index(inactive: "1")

      expect(response.body).to include("gamble")
    end

    # Narrowing happens in the browser, so what the server owes the page is the values each row is matched on. They
    # are the same three the clear form submits, which is what keeps what is shown and what is cleared in step.
    it "gives every row the values the filters match against" do
      allow_access(denied: false)
      create_cooldown(steam_uid: player.steam_uid, command_name: "me")
      create_cooldown(steam_uid: player.steam_uid, command_name: "gamble", target: other_server)

      get_index

      matched = table_rows.map { |row| [row["data-player"], row["data-command"], row["data-server"]] }

      expect(matched).to contain_exactly(
        [player.steam_uid, "me", server.public_id],
        [player.steam_uid, "gamble", other_server.public_id]
      )
    end

    # A community-scoped command has no server to pin its cooldown to, and naming a server has to exclude it. Blank
    # is how the row says so, matching what passing server_id to the command does with it.
    it "leaves the server blank on a row that has none" do
      allow_access(denied: false)
      create_cooldown(steam_uid: player.steam_uid, command_name: "reset_cooldown", target: nil)

      get_index

      expect(table_rows.first["data-server"]).to eq("")
    end

    it "404s someone without permission" do
      allow_access(denied: true, reason: :not_allowlisted)

      get_index

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /cooldowns/clear" do
    it "dispatches reset_cooldown with the filters the table was showing" do
      allow_access(denied: false)

      expect {
        post_clear(player: player.steam_uid, command: "me", server: server.public_id)
      }.to change(ESM::ServiceCommand, :count).by(1)

      command = ESM::ServiceCommand.last
      expect(command.command_name).to eq("reset_cooldown")
      expect(command.arguments).to include(
        community_id: community.community_id,
        target: player.steam_uid,
        command: "me",
        server_id: server.server_id
      )
      expect(ESM::Service::API).to have_received(:call).with(:async_command, command_id: command.id)
    end

    # An unfiltered clear is the whole community, and the command reads an absent argument as "all". Sending a blank
    # one instead would have it looking for a player or a server named "".
    it "omits the arguments no filter was set for" do
      allow_access(denied: false)

      post_clear

      arguments = ESM::ServiceCommand.last.arguments
      expect(arguments).not_to have_key(:target)
      expect(arguments).not_to have_key(:command)
      expect(arguments).not_to have_key(:server_id)
    end

    # The page posts a server's public_id and the command wants its server_id, so the translation happens here rather
    # than the browser being trusted to send something the command will go looking for.
    it "refuses a server that is not this community's" do
      allow_access(denied: false)
      foreign_server = create(:server, community: create(:community))

      expect { post_clear(server: foreign_server.public_id) }.not_to change(ESM::ServiceCommand, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "reports the count back once the command has settled" do
      allow_access(denied: false)
      # The poll's own block is what reloads the controller's copy of the row, so settling the record is only half of
      # it: the block has to run afterwards or the response renders the stale, still-pending object.
      allow(Poll).to receive(:until) do |*, &block|
        ESM::ServiceCommand.last.update!(status: :completed, result: {cleared: 3})
        block&.call
      end

      post_clear

      # A toast rather than an alert in the page, because the card underneath is replaced in the same response.
      expect(response.body).to include("3 cooldowns cleared.")
      expect(response.body).to include("toast-container")
      expect(response.body).to include("cooldowns_card")
    end

    it "reports a denial as a toast" do
      allow_access(denied: true, reason: :not_allowlisted)

      post_clear

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("toast-container")
      expect(response.body).to include("You do not have permission to clear cooldowns")
    end
  end
end
