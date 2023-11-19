# frozen_string_literal: true

describe ESM::Command::Territory::Pay, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    context "when the execution is valid" do
      it "returns a success message" do
        request = execute!(
          channel_type: :dm,
          arguments: {server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5]}
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/has successfully received the payment/i)
      end
    end
  end
end
