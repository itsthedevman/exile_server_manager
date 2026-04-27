# frozen_string_literal: true

describe ESM::Command::Territory::Remove, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

      context "when the target is a registered user" do
        it "removes them from the territory" do
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
            /hey #{user.mention}, `#{second_user.steam_uid}` has been removed from territory `#{territory_id}` on `#{server.server_id}`/i
          )
        end
      end

      context "when the target is an unregistered user" do
        it "raises an exception" do
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

      context "when the user is an unregistered steam uid" do
        it "removes the player from the territory" do
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
            /hey #{user.mention}, `#{steam_uid}` has been removed from territory `#{territory_id}` on `#{server.server_id}`/i
          )
        end
      end
    end
  end

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let(:target) { second_user.mention }
      let(:target_uid) { second_user.steam_uid }

      subject(:execute_command) do
        execute!(
          arguments: {
            target:,
            territory_id: territory.encoded_id,
            server_id: server.server_id
          }
        )
      end

      before do
        user.exile_account
        second_user.exile_account

        territory.create_flag
      end

      shared_examples "succeeds" do
        it "removes the target from the territory" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)

          # Player response
          expect(
            ESM::Test.messages.retrieve("`#{target_uid}` has been removed")
          ).not_to be(nil)

          # Admin log
          expect(
            ESM::Test.messages.retrieve("Player removed Target from territory")
          ).not_to be(nil)

          territory.reload

          expect(territory.moderators).not_to include(target_uid)
          expect(territory.build_rights).not_to include(target_uid)
        end
      end

      context "when the player is a moderator and they remove another territory member" do
        before do
          territory.add_moderators!(user.steam_uid, second_user.steam_uid)
        end

        include_examples "succeeds"
      end

      context "when the player is a member of the territory and they remove themselves" do
        let!(:target) { user.mention }
        let!(:target_uid) { user.steam_uid }

        before do
          territory.add_moderator!(user.steam_uid)
        end

        include_examples "succeeds"
      end

      context "when the player is a territory admin and they remove another territory member" do
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          expect(territory.moderators).not_to include(user.steam_uid)

          territory.add_moderators!(second_user.steam_uid)
        end

        include_examples "succeeds"
      end

      context "when the player is a territory admin and they remove themselves" do
        let!(:territory_admin_uids) { [user.steam_uid] }
        let!(:target) { user.mention }
        let!(:target_uid) { user.steam_uid }

        include_examples "succeeds"
      end

      context "when the player is a moderator and they remove another territory member by UID" do
        let!(:target) { second_user.steam_uid }

        before do
          territory.add_moderators!(user.steam_uid, second_user.steam_uid)
        end

        include_examples "succeeds"
      end

      context "when logging is enabled" do
        before do
          territory.add_moderators!(user.steam_uid, second_user.steam_uid)
          server.server_setting.update!(logging_remove_player_from_territory: true)
        end

        include_examples "arma_discord_logging_enabled" do
          let(:message) { "`ESMs_command_remove` executed successfully" }
        end
      end

      context "when logging is disabled" do
        before do
          territory.add_moderators!(user.steam_uid, second_user.steam_uid)
          server.server_setting.update!(logging_remove_player_from_territory: false)
        end

        include_examples "arma_discord_logging_disabled" do
          let(:message) { "`ESMs_command_remove` executed successfully" }
        end
      end

      context "when the territory is null" do
        before { territory.delete_flag }

        include_examples "arma_error_null_flag"
      end

      context "when the player hasn't joined the server" do
        before { user.exile_account.destroy! }

        include_examples "arma_error_player_needs_to_join"
      end

      context "when the target hasn't joined the server" do
        before { second_user.exile_account.destroy! }

        include_examples "arma_error_target_needs_to_join"
      end

      context "when the player is not a member of the territory" do
        include_examples "arma_error_missing_territory_access"
      end

      context "when the player is a builder in the territory" do
        before { territory.add_builder!(user.steam_uid) }

        include_examples "arma_error_missing_territory_access"
      end

      context "when the target is the owner" do
        let!(:target) { territory.owner_uid }
        let!(:target_uid) { territory.owner_uid }

        before { territory.add_moderators!(user.steam_uid) }

        it "raise Remove_CannotRemoveOwner" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("you have no power here")
          end
        end
      end

      context "when the target is not a member of the territory" do
        before { territory.add_moderators!(user.steam_uid) }

        it "raise Remove_CannotRemoveNothing" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("you can't remove someone you have no power over")
          end
        end
      end
    end
  end
end
