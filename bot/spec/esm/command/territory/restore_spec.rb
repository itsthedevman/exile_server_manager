# frozen_string_literal: true

describe ESM::Command::Territory::Restore, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

    before do
      grant_command_access!(community, "restore")
    end

    context "when the territory has been soft deleted due to missing payment" do
      it "restores the territory" do
        wsc.flags.SUCCESS = true

        request = execute!(arguments: {server_id: server.server_id, territory_id: territory_id})
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to eq("Hey #{user.mention}, `#{territory_id}` has been restored")
      end
    end

    context "when the territory has been hard deleted from the database" do
      it "fails to restore the territory and returns a message" do
        wsc.flags.SUCCESS = false

        request = execute!(arguments: {server_id: server.server_id, territory_id: territory_id})
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to eq("I'm sorry #{user.mention}, `#{territory_id}` no longer exists on `#{server.server_id}`.")
      end
    end
  end
end
