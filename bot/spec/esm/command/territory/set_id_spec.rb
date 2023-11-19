# frozen_string_literal: true

describe ESM::Command::Territory::SetId, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    context "when the old and new IDs are valid" do
      it "changes the ID and returns a success method" do
        request = execute!(
          channel_type: :dm,
          arguments: {
            server_id: server.server_id,
            old_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30),
            new_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..20)
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/you can now use this id wherever/i)
        expect(embed.color).to eq(ESM::Color::Toast::GREEN)
      end
    end

    context "when the provided ID is less than 3 characters" do
      it "raises an exception" do
        execution_args = {
          channel_type: :dm,
          arguments: {
            server_id: server.server_id,
            old_territory_id: Faker::Alphanumeric.alphanumeric(number: 2),
            new_territory_id: Faker::Alphanumeric.alphanumeric(number: 2)
          }
        }

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure, /must be at least 3/i)
      end
    end

    context "when the provided ID is more than 20 characters" do
      it "raises an exception" do
        execution_args = {
          channel_type: :dm,
          arguments: {
            server_id: server.server_id,
            old_territory_id: Faker::Alphanumeric.alphanumeric(number: 21),
            new_territory_id: Faker::Alphanumeric.alphanumeric(number: 21)
          }
        }

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure, /cannot be longer than 20/i)
      end
    end

    context "when the server rejects the request" do
      it "returns an error from the server" do
        wsc.flags.FAIL_WITH_REASON = true

        request = execute!(
          channel_type: :dm,
          arguments: {
            server_id: server.server_id,
            old_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30),
            new_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..20)
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/some reason/i)
        expect(embed.color).to eq(ESM::Color::Toast::RED)
      end
    end

    context "when the user is not the owner" do
      it "returns an error from the server" do
        wsc.flags.FAIL_WITHOUT_REASON = true

        request = execute!(
          channel_type: :dm,
          arguments: {
            server_id: server.server_id,
            old_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..30),
            new_territory_id: Faker::Alphanumeric.alphanumeric(number: 3..20)
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/you are not allowed to do that/i)
        expect(embed.color).to eq(ESM::Color::Toast::RED)
      end
    end
  end
end
