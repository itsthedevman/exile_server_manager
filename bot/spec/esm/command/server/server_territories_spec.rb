# frozen_string_literal: true

describe ESM::Command::Server::ServerTerritories, category: "command" do
  describe "V1" do
    let!(:command) { ESM::Command::Server::ServerTerritories.new }

    it "should be valid" do
      expect(command).not_to be_nil
    end

    it "should have 2 argument" do
      expect(command.arguments.size).to eq(2)
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
      let(:second_user) { ESM::Test.user }
      let!(:wsc) { WebsocketClient.new(server) }
      let(:connection) { ESM::Websocket.connections[server.server_id] }
      let(:response) { command.response }

      before :each do
        # Grant everyone access to use this command
        configuration = community.command_configurations.where(command_name: "server_territories").first
        configuration.update(whitelist_enabled: false)

        wait_for { wsc.connected? }.to be(true)
      end

      after :each do
        wsc.disconnect!
      end

      it "should return (Default)" do
        request = nil
        command_statement = command.statement(server_id: server.server_id)
        event = CommandEvent.create(command_statement, user: user, channel_type: :text)

        expect { request = command.execute(event) }.not_to raise_error
        expect(request).not_to be_nil
        wait_for { ESM::Test.messages.size }.to be > 3
      end

      it "should return (Sorted by territory name)" do
        command_statement = command.statement(server_id: server.server_id, order_by: "territory_name")
        event = CommandEvent.create(command_statement, user: user, channel_type: :text)

        expect { command.execute(event) }.not_to raise_error
        request = connection.requests.first

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to be > 3
        expect(response).to eq(request.response.sort_by(&:territory_name))
      end

      it "should return (Sorted by owner uid)" do
        command_statement = command.statement(server_id: server.server_id, order_by: "owner_uid")
        event = CommandEvent.create(command_statement, user: user, channel_type: :text)

        expect { command.execute(event) }.not_to raise_error
        request = connection.requests.first

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to be > 3
        expect(response).to eq(request.response.sort_by(&:owner_uid))
      end

      it "should return (No territories)" do
        wsc.flags.RETURN_NO_TERRITORIES = true
        request = nil
        command_statement = command.statement(server_id: server.server_id, order_by: "owner_uid")
        event = CommandEvent.create(command_statement, user: user, channel_type: :text)

        expect { request = command.execute(event) }.not_to raise_error
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        expect(ESM::Test.messages.first.second.description).to eq("Hey #{user.mention}, I was unable to find any territories on `#{server.server_id}`")
      end
    end
  end

  describe "V2", category: "command", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an admin command" do
      expect(command.type).to eql(:admin)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    # Change "requires_connection" to true if this command requires the client to be connected
    describe "#on_execute/#on_response", requires_connection: true do
      include_context "connection"

      before do
        grant_command_access!(community, "server_territories")
        ESM::ExileTerritory.delete_all
      end

      let(:territories) do
        5.times.map do
          owner_uid = ESM::Test.steam_uid
          create(
            :exile_territory,
            owner_uid: owner_uid,
            moderators: [owner_uid, user.steam_uid],
            build_rights: [owner_uid, user.steam_uid],
            server_id: server.id
          )
        end
      end

      # Lines
      # 1     - Code block
      # 2     - Top border (Table)
      # 3     - Header
      # 4     - Header separator
      # -3    - Bottom border (table)
      # -2    - Code block
      # -1    - End
      let(:printed_territory_lines) { ESM::Test.messages.first.content.split("\n")[4..-3] }

      it "returns all of territories encoded IDs, names, and owner UIDs - sorted by territory name" do
        territories.sort_by!(&:name)
        execute!(server_id: server.server_id)
        wait_for { command.timers.on_response.finished? }.to be true

        # This tests the printed data on a per index bases. Since territories is sorted, each line should match
        printed_territory_lines.each_with_index do |line, index|
          territory = territories[index]
          expect(line).to include(territory.name.truncate(20), territory.encoded_id, territory.owner_uid)
        end
      end

      it "returns the territories sorted by id" do
        territories.sort_by!(&:encoded_id)
        execute!(server_id: server.server_id, order_by: "id")
        wait_for { command.timers.on_response.finished? }.to be true

        # This tests the printed data on a per index bases. Since territories is sorted, each line should match
        printed_territory_lines.each_with_index do |line, index|
          territory = territories[index]
          expect(line).to include(territory.name.truncate(20), territory.encoded_id, territory.owner_uid)
        end
      end

      it "returns the territories sorted by owner uid" do
        territories.sort_by!(&:owner_uid)
        execute!(server_id: server.server_id, order_by: "owner_uid")
        wait_for { command.timers.on_response.finished? }.to be true

        # This tests the printed data on a per index bases. Since territories is sorted, each line should match
        printed_territory_lines.each_with_index do |line, index|
          territory = territories[index]
          expect(line).to include(territory.name.truncate(20), territory.encoded_id, territory.owner_uid)
        end
      end

      it "returns no territories" do
        execute!(server_id: server.server_id)
        wait_for { ESM::Test.messages }.not_to be_empty

        embed = ESM::Test.messages.first.content
        expect(embed.description).to eq("Hey #{user.mention}, I was unable to find any territories on `#{server.server_id}`")
      end
    end
  end
end
