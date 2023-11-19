# frozen_string_literal: true

describe ESM::Command::Server::Me, category: "command" do
  describe "V1" do
    include_context "command"
    include_examples "validate_command"

    describe "#execute" do
      include_context "connection_v1"

      context "when the command is executed" do
        it "returns information about the player" do
          execute!(arguments: {server_id: server.server_id})
          request = connection.requests.first

          wait_for { connection.requests }.to be_blank
          expect(ESM::Test.messages).not_to be_blank

          embed = ESM::Test.messages.first.content
          server_response = request.command.response

          expect(embed.title).to match(/.+'s stats on `#{server.server_id}`/)
          expect(embed.fields.size).to be >= 3

          if server_response.territories.present?
            expect(embed.fields.size).to eq(4)
            expect(embed.fields[3].name).to eq("__Territories__")
            expect(embed.fields[3].value).not_to be_blank
          end
        end
      end
    end
  end

  describe "V2", category: "command", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an player command" do
      expect(command.type).to eq(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    # Change "requires_connection" to true if this command requires the client to be connected
    describe "#on_execute/#on_response", :requires_connection do
      include_context "connection"

      it "returns the user's stats on the server" do
        execute!(server_id: server.server_id)
        wait_for { ESM::Test.messages }.not_to be_empty

        embed = ESM::Test.messages.first.content
        expect(embed.title).to match(/.+'s stats on `#{server.server_id}`/)
        expect(embed.fields.size).to eq(3)
      end

      it "includes territories when the player has territories" do
        owner_uid = ESM::Test.steam_uid

        territories = create_list(
          :exile_territory, 2,
          owner_uid: owner_uid,
          moderators: [owner_uid, user.steam_uid],
          build_rights: [owner_uid, user.steam_uid],
          server_id: server.id
        )

        execute!(server_id: server.server_id)
        wait_for { ESM::Test.messages }.not_to be_empty

        embed = ESM::Test.messages.first.content
        expect(embed.fields.size).to eq(4)
        expect(embed.fields[3].name).to eq("__Territories__")

        territories.each do |territory|
          expect(embed.fields[3].value).to include(territory.encoded_id, territory.name)
        end
      end

      it "displays account information when the player is dead" do
        player = ESM::ExilePlayer.from(user)
        expect(player).not_to be_nil

        player.kill!

        execute!(server_id: server.server_id)
        wait_for { ESM::Test.messages }.not_to be_empty

        embed = ESM::Test.messages.first.content
        general_field = embed.fields.first
        expect(general_field.name).to match("General")
        expect(general_field.value).to match("You are dead")
      end

      it "errors because user has not joined the server" do
        player = ESM::ExilePlayer.from(user)
        player.kill!

        account = ESM::ExileAccount.from(user)
        account.delete

        execute!(server_id: server.server_id)
        wait_for { ESM::Test.messages }.not_to be_empty

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          "Hey #{user.mention}, you **need to join** `#{server.server_id}` first before you can run commands on it"
        )
      end
    end
  end
end
