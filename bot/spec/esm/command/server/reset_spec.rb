# frozen_string_literal: true

describe ESM::Command::Server::Reset, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    before do
      grant_command_access!(community, "reset")
    end

    context "when only a server ID is provided and there are stuck players" do
      it "resets all players" do
        wsc.flags.SUCCESS = true

        execute!(arguments: {server_id: server.server_id})
        wait_for { ESM::Test.messages.size }.to eq(2)

        embed = ESM::Test.messages.first.content

        # Checks for requestors message
        expect(embed).not_to be_nil

        # Checks for requestees message
        expect(ESM::Test.messages.size).to eq(2)

        # Process the request
        request = previous_command.request
        expect(request).not_to be_nil

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Respond to the request
        request.respond(true)

        wait_for { connection.requests }.to be_blank

        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.content

        expect(embed.description).to match(/i've reset all stuck players\./i)
      end
    end

    context "when only the server ID is provided and there are no stuck players" do
      it "does not reset anyone and it returns a general message" do
        wsc.flags.SUCCESS = false

        execute!(arguments: {server_id: server.server_id})
        wait_for { ESM::Test.messages.size }.to eq(2)

        embed = ESM::Test.messages.first.content

        # Checks for requestors message
        expect(embed).not_to be_nil

        # Checks for requestees message
        expect(ESM::Test.messages.size).to eq(2)

        # Process the request
        request = previous_command.request
        expect(request).not_to be_nil

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Respond to the request
        request.respond(true)

        wait_for { connection.requests }.to be_blank

        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.content

        expect(embed.description).to match(/i was unable to find anyone who was stuck\./i)
      end
    end

    context "when a target is provided and player is stuck" do
      it "resets the player" do
        wsc.flags.SUCCESS = true

        execute!(arguments: {server_id: server.server_id, target: second_user.steam_uid})
        wait_for { ESM::Test.messages.size }.to eq(2)

        embed = ESM::Test.messages.first.content

        # Checks for requestors message
        # Checks for requestees message
        expect(embed).not_to be_nil

        # Process the request
        request = previous_command.request
        expect(request).not_to be_nil

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Respond to the request
        request.respond(true)

        wait_for { connection.requests }.to be_blank

        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.content

        expect(embed.description).to match(/has been reset successfully. please instruct them to join the server again to confirm\./i)
      end
    end

    context "when the target is an unregistered steam uid" do
      it "resets the player" do
        wsc.flags.SUCCESS = true

        steam_uid = second_user.steam_uid
        second_user.destroy

        execute!(arguments: {server_id: server.server_id, target: steam_uid})
        wait_for { ESM::Test.messages.size }.to eq(2)

        embed = ESM::Test.messages.first.content

        # Checks for requestors message
        expect(embed).not_to be_nil

        # Process the request
        request = previous_command.request
        expect(request).not_to be_nil

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Respond to the request
        request.respond(true)

        wait_for { connection.requests }.to be_blank

        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.content

        expect(embed.description).to match(/has been reset successfully. please instruct them to join the server again to confirm\./i)
      end
    end

    context "when the target is not stuck" do
      it "does not reset the user and returns a general message" do
        wsc.flags.SUCCESS = false

        execute!(arguments: {server_id: server.server_id, target: second_user.mention})
        wait_for { ESM::Test.messages.size }.to eq(2)

        embed = ESM::Test.messages.first.content

        # Checks for requestors message
        expect(embed).not_to be_nil

        # Process the request
        request = previous_command.request
        expect(request).not_to be_nil

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Respond to the request
        request.respond(true)

        wait_for { connection.requests }.to be_blank

        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.content

        expect(embed.description).to match(/is not stuck\. please have them join the server again, and if they are still stuck, instruct them to close arma 3 and then attempt this command again\./i)
      end
    end
  end
end
