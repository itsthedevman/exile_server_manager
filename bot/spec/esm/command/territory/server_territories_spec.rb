# frozen_string_literal: true

describe ESM::Command::Territory::ServerTerritories, category: "command" do
  describe "V1" do
    include_context "command"
    include_examples "validate_command"

    describe "#execute" do
      include_context "connection_v1"

      before do
        grant_command_access!(community, "server_territories")
      end

      context "when no order was provided" do
        it "orders the results by id" do
          execute!(arguments: {server_id: server.server_id})

          request = connection.requests.first
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to be > 3

          expect(previous_command.arguments.order_by).to eq("territory_name")
          expect(response).to eq(request.response.sort_by(&:territory_name))
        end
      end

      context "when the order is by name" do
        it "orders the results by name" do
          execute!(arguments: {server_id: server.server_id, order_by: "territory_name"})

          request = connection.requests.first
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to be > 3

          expect(previous_command.arguments.order_by).to eq("territory_name")
          expect(response).to eq(request.response.sort_by(&:territory_name))
        end
      end

      context "when the order is by owner uid" do
        it "orders the results by owner uid" do
          execute!(arguments: {server_id: server.server_id, order_by: "owner_uid"})

          request = connection.requests.first
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to be > 3

          expect(previous_command.arguments.order_by).to eq("owner_uid")
          expect(response).to eq(request.response.sort_by(&:owner_uid))
        end
      end

      context "when there are no territories" do
        it "returns a default message" do
          wsc.flags.RETURN_NO_TERRITORIES = true

          execute!(arguments: {server_id: server.server_id, order_by: "owner_uid"})

          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to eq(
            "Hey #{user.mention}, I was unable to find any territories on `#{server.server_id}`"
          )
        end
      end
    end
  end

  describe "V2", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an admin command" do
      expect(command.type).to eq(:admin)
    end

    describe "#on_execute/#on_response", :requires_connection do
      include_context "connection"

      before do
        grant_command_access!(community, "server_territories")
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
        execute!(arguments: {server_id: server.server_id})

        # This tests the printed data on a per index bases. Since territories is sorted, each line should match
        printed_territory_lines.each_with_index do |line, index|
          territory = territories[index]
          expect(line).to include(territory.name.truncate(20), territory.encoded_id, territory.owner_uid)
        end
      end

      it "returns the territories sorted by id" do
        territories.sort_by!(&:encoded_id)
        execute!(arguments: {server_id: server.server_id, order_by: "id"})

        # This tests the printed data on a per index bases. Since territories is sorted, each line should match
        printed_territory_lines.each_with_index do |line, index|
          territory = territories[index]
          expect(line).to include(territory.name.truncate(20), territory.encoded_id, territory.owner_uid)
        end
      end

      it "returns the territories sorted by owner uid" do
        territories.sort_by!(&:owner_uid)
        execute!(arguments: {server_id: server.server_id, order_by: "owner_uid"})

        # This tests the printed data on a per index bases. Since territories is sorted, each line should match
        printed_territory_lines.each_with_index do |line, index|
          territory = territories[index]
          expect(line).to include(territory.name.truncate(20), territory.encoded_id, territory.owner_uid)
        end
      end

      it "returns no territories" do
        execute!(handle_error: true, arguments: {server_id: server.server_id})
        wait_for { ESM::Test.messages }.not_to be_empty

        embed = ESM::Test.messages.first.content
        expect(embed.description).to eq("Hey #{user.mention}, I was unable to find any territories on `#{server.server_id}`")
      end
    end
  end
end
