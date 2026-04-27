# frozen_string_literal: true

describe ESM::Command::Territory::SetId, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
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

  describe "V2", v2: true do
    include_context "command", described_class
    include_examples "validate_command"

    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let!(:old_territory_id) { territory.encoded_id }
      let!(:new_territory_id) { Faker::Alphanumeric.alphanumeric(number: 10) }

      subject(:execute_command) do
        execute!(
          channel_type: :dm,
          arguments: {
            server_id: server.server_id,
            old_territory_id:,
            new_territory_id:
          }
        )
      end

      ##########################################################################

      shared_examples "sets the ID" do
        it "updates the ID" do
          expect { execute_command }.not_to raise_error

          territory.reload

          expect(territory.esm_custom_id).to eq(new_territory_id)
          expect(ESM::Test.messages.retrieve("ID is now")).not_to be(nil)
        end
      end

      shared_examples "raises territory_id_does_not_exist" do
        it "raises an exception" do
          expect { execute_command }.to raise_error(
            ESM::Exception::ExtensionError,
            /I was unable to find an active territory/i
          )
        end
      end

      ##########################################################################

      describe "when the user is the owner" do
        context "and the old territory ID is an encoded ID" do
          before do
            user.exile_account # The UID must be in the account table (FK)
            territory.change_owner(user.steam_uid)
          end

          include_examples "sets the ID"
        end

        context "and the old territory ID is a custom ID" do
          let!(:old_territory_id) { Faker::Alphanumeric.alphanumeric(number: 10) }

          before do
            user.exile_account # The UID must be in the account table (FK)

            # The call to #change_owner saves the territory
            territory.esm_custom_id = old_territory_id
            territory.change_owner(user.steam_uid)
          end

          include_examples "sets the ID"
        end
      end

      context "when the user is a territory admin" do
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "sets the ID"
      end

      context "when the provided ID is less than 3 characters" do
        let!(:old_territory_id) { Faker::Alphanumeric.alphanumeric(number: 2) }
        let!(:new_territory_id) { Faker::Alphanumeric.alphanumeric(number: 2) }

        it "raises an exception" do
          expect { execute_command }.to raise_error(
            ESM::Exception::CheckFailure,
            /must be at least 3/i
          )
        end
      end

      context "when the provided ID is more than 20 characters" do
        let!(:old_territory_id) { Faker::Alphanumeric.alphanumeric(number: 22) }
        let!(:new_territory_id) { Faker::Alphanumeric.alphanumeric(number: 22) }

        it "raises an exception" do
          expect { execute_command }.to raise_error(
            ESM::Exception::CheckFailure,
            /cannot be longer than 20/i
          )
        end
      end

      context "when the user is not the owner" do
        before do
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "raises territory_id_does_not_exist"
      end

      context "when the provided territory ID does not exist in the database" do
        let!(:old_territory_id) { "this_cannot_exist" }

        include_examples "raises territory_id_does_not_exist"
      end
    end
  end
end
