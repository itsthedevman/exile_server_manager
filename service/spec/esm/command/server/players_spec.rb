# frozen_string_literal: true

describe ESM::Command::Server::Players, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is an admin command" do
    expect(command.type).to eq(:admin)
  end

  before do
    grant_command_access!(community, "players")
  end

  describe "V1" do
    include_context "connection_v1"

    subject(:execute_command) { execute!(arguments: {server_id: server.server_id}) }

    include_examples "raises_server_version_not_supported"
  end

  describe "V2", v2: true do
    # Discord answers "who is on right now" and sizes its own window, so neither of these reaches it.
    it "keeps the query arguments off of Discord" do
      expect(command.arguments.templates[:connected_since].available_to?(:discord)).to be(false)
      expect(command.arguments.templates[:limit].available_to?(:discord)).to be(false)
    end

    describe "#on_execute", :requires_connection do
      include_context "connection"

      subject(:execute_command) { execute!(arguments: {server_id: server.server_id}) }

      let!(:online_account) { create(:exile_account, uid: Faker::Steam.uid) }

      it "replies with the online players and their UIDs" do
        execute_command
        wait_for { ESM.discord_bot.test_outbox }.not_to be_empty

        table = ESM.discord_bot.test_outbox.first.content
        expect(table).to include(online_account.name, online_account.uid)
      end

      # `online` is derived from the connect/disconnect pair, not stored, so someone who connected inside the window
      # and has since left still comes back from the query. The command has to drop them itself.
      context "when everyone in the window has since disconnected" do
        let!(:online_account) do
          create(
            :exile_account,
            uid: Faker::Steam.uid,
            last_connect_at: 1.hour.ago,
            last_disconnect_at: 1.minute.ago
          )
        end

        include_examples "raises_check_failure" do
          let!(:matcher) { "there's no one online on `#{server.server_id}`" }
        end
      end

      # The window is derived from the server's restart interval: nobody can stay connected across a restart, so a
      # connection older than one is a stale `last_disconnect_at` rather than a player who is still on.
      context "when a player connected before the last restart" do
        let!(:stale_account) do
          create(
            :exile_account,
            uid: Faker::Steam.uid,
            last_connect_at: server.restart_interval.ago - 1.hour
          )
        end

        it "leaves them out" do
          execute_command
          wait_for { ESM.discord_bot.test_outbox }.not_to be_empty

          table = ESM.discord_bot.test_outbox.first.content
          expect(table).to include(online_account.name)
          expect(table).not_to include(stale_account.name)
        end
      end
    end

    # The website supplies its own window and page size, and it wants the full picture rather than only who is on.
    describe "#on_website_execute", :requires_connection do
      include_context "connection"

      subject(:players) do
        execute_sync!(
          arguments: {
            server_id: server.server_id,
            connected_since: 1.day.ago,
            limit: 50
          }
        )
      end

      let!(:online_account) { create(:exile_account, uid: Faker::Steam.uid) }

      let!(:offline_account) do
        create(
          :exile_account,
          uid: Faker::Steam.uid,
          last_connect_at: 1.hour.ago,
          last_disconnect_at: 1.minute.ago
        )
      end

      it "returns everyone in the window, online or not" do
        expect(players.map { |player| player[:uid] })
          .to contain_exactly(online_account.uid, offline_account.uid)
      end

      it "flags who is currently online" do
        by_uid = players.index_by { |player| player[:uid] }

        expect(by_uid[online_account.uid][:online]).to be(true)
        expect(by_uid[offline_account.uid][:online]).to be(false)
      end

      # The window the website sends is honored as-is rather than being widened to the restart interval.
      context "when a player connected before the given window" do
        let!(:offline_account) do
          create(:exile_account, uid: Faker::Steam.uid, last_connect_at: 2.days.ago)
        end

        it "leaves them out" do
          expect(players.map { |player| player[:uid] }).to contain_exactly(online_account.uid)
        end
      end
    end
  end
end
