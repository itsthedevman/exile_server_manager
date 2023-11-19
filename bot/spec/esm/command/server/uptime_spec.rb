# frozen_string_literal: true

describe ESM::Command::Server::Uptime, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    context "when the server is connected" do
      it "returns the uptime for the server" do
        execute!(arguments: {server_id: server.server_id})

        embed = ESM::Test.messages.first.content

        expect(embed.description).to match(/`#{server.server_id}` has been online for \d+ seconds?/i)
      end
    end
  end
end
