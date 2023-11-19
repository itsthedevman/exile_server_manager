# frozen_string_literal: true

describe ESM::Command::Territory::Promote, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

    context "when the target is a registered user" do
      it "promotes the user" do
        request = execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory_id,
            target: second_user.mention
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          /hey #{user.mention}, `#{second_user.steam_uid}` has been promoted to moderator in territory `#{territory_id}` on `#{server.server_id}`/i
        )
      end
    end

    context "when the target is an unregistered user" do
      it "promotes the user" do
        second_user.update!(steam_uid: "")

        execution_args = {
          arguments: {
            server_id: server.server_id,
            territory_id: territory_id,
            target: second_user.mention
          }
        }

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match(/has not registered with me yet/i)
        end
      end
    end

    context "when the target is an unregistered steam uid" do
      it "promotes the user" do
        steam_uid = second_user.steam_uid
        second_user.update!(steam_uid: "")

        request = execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory_id,
            target: steam_uid
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          /hey #{user.mention}, `#{steam_uid}` has been promoted to moderator in territory `#{territory_id}` on `#{server.server_id}`/i
        )
      end
    end
  end
end
