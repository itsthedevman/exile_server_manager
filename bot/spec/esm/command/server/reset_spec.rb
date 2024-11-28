# frozen_string_literal: true

describe ESM::Command::Server::Reset, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is an admin command" do
    expect(command.type).to eq(:admin)
  end

  before do
    grant_command_access!(community, "reset")
  end

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

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

  describe "V2", v2: true do
    describe "#on_execute", :requires_connection do
      include_context "connection"

      let(:arguments) { {} }

      subject(:execute_command) { execute!(arguments:) }

      before do
        # So there is at least one non-stuck player
        account = create(:exile_account, uid: ESM::Test.steam_uid)
        create(:exile_player, account_uid: account.uid)
      end

      context "when the target is not provided" do
        let!(:arguments) { {server_id: server.server_id} }

        let!(:players) do
          5.times.map do
            account = create(:exile_account, uid: ESM::Test.steam_uid)

            # Important bit here -> damage: 1
            create(:exile_player, account_uid: account.uid, damage: 1)
          end
        end

        it "resets all stuck players" do
          expect(ESM::ExilePlayer.all.size).to eq(6)

          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          wait_for { ESM::Test.messages.size }.to eq(3)

          embed = latest_message
          expect(embed.description).to match("reset all stuck players")

          # "resetting" involves deleting the player
          expect(ESM::ExilePlayer.all.size).to eq(1)
        end
      end

      context "when a target is provided" do
        shared_examples "resets_player" do
          it "resets the player" do
            expect(ESM::ExilePlayer.all.size).to eq(2)

            execute_command

            wait_for { ESM::Test.messages.size }.to eq(2)

            accept_request

            wait_for { ESM::Test.messages.size }.to eq(3)

            embed = latest_message
            expect(embed.description).to match("has been reset successfully")

            # "resetting" involves deleting the player
            expect(ESM::ExilePlayer.all.size).to eq(1)
          end
        end

        context "and the target is a registered user" do
          let!(:arguments) { {target: user.mention, server_id: server.server_id} }

          before do
            # Important bit here -> damage: 1
            user.exile_player.update!(damage: 1)
          end

          include_examples "resets_player"
        end

        context "and the target is a steam uid" do
          let!(:arguments) { {target: player.account_uid, server_id: server.server_id} }

          let!(:player) do
            account = create(:exile_account, uid: ESM::Test.steam_uid)

            # Important bit here -> damage: 1
            create(:exile_player, account_uid: account.uid, damage: 1)
          end

          include_examples "resets_player"
        end
      end

      context "when the player already has a request" do
        let!(:arguments) { {server_id: server.server_id} }

        before do
          # Executing the command but not handling the request will cause the request to be pending
          execute!(arguments:)
          previous_command.current_cooldown.reset!
        end

        # This will then trigger the command again to cause the error
        include_examples "raises_check_failure" do
          let!(:matcher) { "request pending" }
        end
      end
    end
  end
end
