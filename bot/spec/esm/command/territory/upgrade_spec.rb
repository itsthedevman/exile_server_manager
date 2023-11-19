# frozen_string_literal: true

describe ESM::Command::Territory::Upgrade, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

    context "when the territory can be upgraded" do
      it "is upgraded to the next level" do
        request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, territory_id: territory_id})
        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to eq("Hey #{user.mention}, you successfully upgraded territory `#{territory_id}` for **#{response.cost.to_poptab}**.\nYour territory has reached level **#{response.level}** and now has a radius of **#{response.range}** meters.\nAfter this transaction, you have **#{response.locker.to_poptab}** left in your locker.")
      end
    end
  end
end
