# frozen_string_literal: true

describe ESM::Command::Territory::Promote, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
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

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let!(:territory) do
        owner_uid = ESM::Test.steam_uid
        create(
          :exile_territory,
          owner_uid: owner_uid,
          moderators: [owner_uid, user.steam_uid],
          build_rights: [owner_uid, user.steam_uid, second_user.steam_uid],
          server_id: server.id
        )
      end

      before do
        user.exile_account
        second_user.exile_account

        territory.create_flag
      end

      subject(:execute_command) do
        execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory.encoded_id,
            target: second_user.steam_uid
          }
        )
      end

      shared_examples "successful_promotion" do
        it "promotes the target" do
          expect(territory.moderators).not_to include(second_user.steam_uid)

          execute_command
          territory.reload

          expect(territory.moderators).to include(second_user.steam_uid)
          expect(territory.build_rights).to include(second_user.steam_uid)

          expect(
            ESM::Test.messages.retrieve(
              /`#{second_user.mention}` has been promoted to moderator in territory `#{territory.encoded_id}`/i
            )
          ).not_to be_nil
        end
      end

      context "when the player is a moderator and the target is a builder" do
        include_examples "successful_promotion"
      end

      context "when logging is enabled" do
        before do
          server.server_setting.update!(logging_promote_player: true)
        end

        include_examples "arma_discord_logging_enabled" do
          let(:message) { "`ESMs_command_promote` executed successfully" }
        end
      end

      context "when logging is disabled" do
        before do
          server.server_setting.update!(logging_promote_player: false)
        end

        include_examples "arma_discord_logging_disabled" do
          let(:message) { "`ESMs_command_promote` executed successfully" }
        end
      end

      context "when the player is a territory admin and the target is a builder" do
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "successful_promotion"
      end

      context "when the territory flag is null" do
        before { territory.delete_flag }

        include_examples "arma_error_null_flag"
      end

      context "when the player has not joined the server" do
        before { user.exile_account.destroy! }

        include_examples "arma_error_player_needs_to_join"
      end

      context "when the target has not joined the server" do
        before { second_user.exile_account.destroy! }

        include_examples "arma_error_target_needs_to_join"
      end

      context "when the player is not a moderator" do
        before do
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "arma_error_missing_territory_access"
      end

      context "when the target is not a member" do
        before do
          territory.revoke_membership(second_user.steam_uid)
        end

        it "raises Promote_MissingRights" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("#{second_user.mention} is not a member this territory")
          end
        end
      end

      context "when the target is already a moderator" do
        before do
          territory.add_moderator!(second_user.steam_uid)
        end

        it "raises Promote_ExistingRights" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("#{second_user.mention} is already a moderator")
          end
        end
      end
    end
  end
end
