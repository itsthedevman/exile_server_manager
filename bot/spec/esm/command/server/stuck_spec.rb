# frozen_string_literal: true

describe ESM::Command::Server::Stuck, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when the user is stuck" do
        it "resets the player" do
          wsc.flags.SUCCESS = true
          execute!(arguments: {server_id: server.server_id})

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

          expect(embed.description).to match(/you've been reset successfully. please join the server to spawn back in/i)
        end
      end

      context "when the user is not stuck" do
        it "returns an error" do
          wsc.flags.SUCCESS = false

          execute!(arguments: {server_id: server.server_id})

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

          expect(embed.description).to match(
            /i was not successful at resetting your player on `.+`\. please join the server again, and if you are still stuck, close arma 3 and attempt this command again\./i
          )
        end
      end
    end
  end

  describe "V2", v2: true do
    describe "#on_execute", :requires_connection do
      include_context "connection"

      let!(:player) do
        account = create(:exile_account, uid: ESM::Test.steam_uid)

        # Important bit here -> damage: 1
        create(:exile_player, account_uid: account.uid, damage: 1)
      end

      subject(:execute_command) { execute!(arguments: {server_id: server.server_id}) }

      before do
        # So there is a non-stuck player
        user.exile_player
      end

      context "when the user does not have a pending request" do
        it "resets the player" do
          expect(ESM::ExilePlayer.all.size).to eq(2)

          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          wait_for { ESM::Test.messages.size }.to eq(3)

          embed = latest_message
          expect(embed.description).to match("you've been reset successfully")

          # "resetting" involves deleting the player
          expect(ESM::ExilePlayer.all.size).to eq(1)
        end
      end

      context "when the player already has a request" do
        before do
          # Executing the command but not handling the request will cause the request to be pending
          execute!(arguments: {server_id: server.server_id})
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
