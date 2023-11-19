# frozen_string_literal: true

describe ESM::Command::Server::Stuck, category: "command" do
  include_context "command"
  include_examples "validate_command"

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
