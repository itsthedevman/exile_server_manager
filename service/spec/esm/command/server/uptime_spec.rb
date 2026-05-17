# frozen_string_literal: true

describe ESM::Command::Server::Uptime, category: "command" do
  include_context "command"
  include_examples "validate_command", requires_registration: false

  describe "#execute" do
    include_context "connection_v1"

    context "when the server is connected" do
      it "returns the uptime for the server" do
        execute!(arguments: {server_id: server.server_id})

        embed = ESM.discord_bot.test_outbox.first.content

        expect(embed.description).to match(/`#{server.server_id}` has been online for (\d+ seconds?|less than 1 second)/i)
      end
    end
  end
end
