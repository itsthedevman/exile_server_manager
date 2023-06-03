# frozen_string_literal: true

describe ESM::Command::Server::Me, category: "command" do
  let!(:command) { ESM::Command::Server::Me.new }

  describe "V1" do
    it "should be valid" do
      expect(command).not_to be_nil
    end

    it "should have 1 argument" do
      expect(command.arguments.size).to eq(1)
    end

    it "should have a description" do
      expect(command.description).not_to be_blank
    end

    it "should have examples" do
      expect(command.example).not_to be_blank
    end

    describe "#execute" do
      let!(:community) { ESM::Test.community }
      let!(:server) { ESM::Test.server }
      let!(:user) { ESM::Test.user }
      let!(:wsc) { WebsocketClient.new(server) }
      let(:connection) { ESM::Websocket.connections[server.server_id] }

      before :each do
        wait_for { wsc.connected? }.to be(true)
      end

      after :each do
        wsc.disconnect!
      end

      it "should return" do
        command_statement = command.statement(server_id: server.server_id)
        event = CommandEvent.create(command_statement, user: user, channel_type: :text)

        expect { command.execute(event) }.not_to raise_error
        request = connection.requests.first

        wait_for { connection.requests }.to be_blank
        expect(ESM::Test.messages).not_to be_blank

        embed = ESM::Test.messages.first.second
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

  describe "V2", category: "command", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an player command" do
      expect(command.type).to eql(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    # Change "requires_connection" to true if this command requires the client to be connected
    describe "#on_execute/#on_response", requires_connection: true do
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
