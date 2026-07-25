# frozen_string_literal: true

describe ESM::Command::Server::Territory, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    include_context "connection_v1"

    subject(:execute_command) do
      execute!(channel_type: :pm, arguments: {server_id: server.server_id, territory_id: "awesome"})
    end

    include_examples "raises_server_version_not_supported"
  end

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    # The website runs the same query but hands back the raw territory for its page. Unlike Discord, a player with no
    # rights to the territory gets nil rather than an error - the page renders its own unavailable state.
    describe "#on_website_execute", :requires_connection do
      include_context "connection"

      subject(:result) do
        execute_sync!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id})
      end

      shared_examples("returns_the_territory") do
        it "is expected to return the territory" do
          exile_territory = ESM::Exile::Territory.new(server: server, territory: result)

          expect(exile_territory.name).to eq(territory.name)
        end
      end

      context "when the player owns the territory" do
        let(:territory_owner) { user.steam_uid }

        include_examples "returns_the_territory"
      end

      context "when the player is a moderator of the territory" do
        let(:territory_moderators) { [user.steam_uid] }

        include_examples "returns_the_territory"
      end

      context "when the player only has build rights on the territory" do
        let(:territory_build_rights) { [user.steam_uid] }

        include_examples "returns_the_territory"
      end

      context "when the player has no rights to the territory" do
        it "is expected to return nil" do
          expect(result).to be_nil
        end
      end
    end

    describe "#on_execute", :requires_connection do
      include_context "connection"

      subject(:execute_command) do
        execute!(
          channel_type: :pm,
          arguments: {server_id: server.server_id, territory_id: territory.encoded_id}
        )
      end

      shared_examples("replies_with_the_territory") do
        it "is expected to reply with the territory" do
          execute_command
          wait_for { ESM.discord_bot.test_outbox }.not_to be_empty

          embed = ESM.discord_bot.test_outbox.first.content
          expect(embed.title).to include(territory.name)
        end
      end

      context "when the player owns the territory" do
        let(:territory_owner) { user.steam_uid }

        include_examples "replies_with_the_territory"
      end

      context "when the player is a moderator of the territory" do
        let(:territory_moderators) { [user.steam_uid] }

        include_examples "replies_with_the_territory"
      end

      context "when the player only has build rights on the territory" do
        let(:territory_build_rights) { [user.steam_uid] }

        include_examples "replies_with_the_territory"
      end

      context "when the player has no rights to the territory" do
        include_examples "raises_check_failure" do
          let!(:matcher) { "you're not a part of the territory `#{territory.encoded_id}`" }
        end
      end

      # A territory ID that matches nothing is rejected by the extension before the command's own check, so this
      # answers with the extension's copy rather than not_a_member.
      context "when no territory has that ID" do
        subject(:execute_command) do
          execute!(
            channel_type: :pm,
            arguments: {server_id: server.server_id, territory_id: "nonexistent"}
          )
        end

        include_examples "error_territory_id_does_not_exist"
      end
    end
  end
end
