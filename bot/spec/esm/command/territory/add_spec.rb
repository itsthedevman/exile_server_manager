# frozen_string_literal: true

describe ESM::Command::Territory::Add, category: "command" do
  describe "V1" do
    include_context "command"
    include_examples "validate_command"

    describe "#execute" do
      include_context "connection_v1"

      context "when the target user is unregistered" do
        it "raises an exception" do
          second_user.update(steam_uid: nil)

          execution_args = {
            channel_type: :dm,
            arguments: {
              server_id: server.server_id,
              territory_id: Faker::Crypto.md5[0, 5],
              target: second_user.mention
            }
          }

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            embed = error.data
            expect(embed.description).to match(/#{second_user.mention} has not registered with me yet. tell them to head over/i)
          end
        end
      end

      context "when the target is an unregistered steam uid" do
        it "raises an exception" do
          steam_uid = second_user.steam_uid
          second_user.update(steam_uid: "")

          execution_args = {
            channel_type: :dm,
            arguments: {
              server_id: server.server_id,
              territory_id: Faker::Crypto.md5[0, 5],
              target: steam_uid
            }
          }

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            expect(error.data.description).to match(/hey #{user.mention}, #{steam_uid} has not registered with me yet/i)
          end
        end
      end

      context "when the target user is registered" do
        it "adds the user" do
          execute!(
            channel_type: :dm,
            arguments: {
              server_id: server.server_id,
              territory_id: Faker::Crypto.md5[0, 5],
              target: second_user.mention
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          embed = ESM::Test.messages.first.content

          # Checks for requestors message
          expect(embed).not_to be_nil

          # Checks for requestees message
          expect(ESM::Test.messages.size).to eq(2)

          # Process the request
          request = previous_command.request
          expect(request).not_to be_nil

          # Respond to the request
          request.respond(true)

          # Reset so we can track the response
          ESM::Test.messages.clear

          # Wait for the server to respond
          wait_for { ESM::Test.messages.size }.to eq(2)

          expect(ESM::Test.messages.size).to eq(2)
        end
      end

      context "when the user is a territory admin" do
        it "adds the user" do
          execute!(
            channel_type: :dm,
            arguments: {
              server_id: server.server_id,
              territory_id: Faker::Crypto.md5[0, 5],
              target: user.mention
            }
          )

          expect(ESM::Test.messages.size).to eq(0)

          # We don't create a request for this
          expect(ESM::Request.all.size).to eq(0)

          # Reset so we can track the response
          ESM::Test.messages.clear

          # Wait for the server to respond
          wait_for { ESM::Test.messages.size }.to eq(1)

          expect(ESM::Test.messages.size).to eq(1)
        end
      end
    end
  end

  describe "V2", category: "command", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an player command" do
      expect(command.type).to eq(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    # Change "requires_connection" to true if this command requires the client to be connected
    describe "#on_execute", :requires_connection do
      include_context "connection"

      let!(:territory) do
        owner_uid = ESM::Test.steam_uid
        create(
          :exile_territory,
          owner_uid: owner_uid,
          moderators: [owner_uid, user.steam_uid],
          build_rights: [owner_uid, user.steam_uid],
          server_id: server.id
        )
      end

      before do
        user.exile_account
        second_user.exile_account

        territory.create_flag
      end

      context "when the user is a moderator and the target is a different player" do
        it "adds the player to the territory, notifies the user and target, and creates a log in the logging channel" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Target's add notification
          # 4: Requestor's confirmation
          # 5: Discord log
          wait_for { ESM::Test.messages.size }.to eq(5)

          # The last messages are not always in order...
          expect(
            ESM::Test.messages.retrieve(/you've been added to `#{territory.encoded_id}` successfully/i)
          ).not_to be_nil

          expect(
            ESM::Test.messages.retrieve(
              /#{second_user.distinct} has been added to territory `#{territory.encoded_id}`/
            )
          ).not_to be_nil

          # Admin log on the community's discord server
          log_message = ESM::Test.messages.retrieve("Player added Target to territory")
          expect(log_message).not_to be_nil
          expect(log_message.destination.id.to_s).to eq(community.logging_channel_id)

          log_embed = log_message.content
          expect(log_embed.fields.size).to eq(3)

          [
            {
              name: "Territory",
              value: "**ID:** #{territory.encoded_id}\n**Name:** #{territory.name}"
            },
            {
              name: "Player",
              value: "**Discord ID:** #{user.discord_id}\n**Steam UID:** #{user.steam_uid}\n**Discord name:** #{user.discord_username}\n**Discord mention:** #{user.mention}"
            },
            {
              name: "Target",
              value: "**Discord ID:** #{second_user.discord_id}\n**Steam UID:** #{second_user.steam_uid}\n**Discord name:** #{second_user.discord_username}\n**Discord mention:** #{second_user.mention}"
            }
          ].each_with_index do |test_field, i|
            field = log_embed.fields[i]
            expect(field).not_to be_nil
            expect(field.name).to eq(test_field[:name])
            expect(field.value).to eq(test_field[:value])
          end

          # Check that Arma update the territory
          territory.reload
          expect(territory.build_rights).to include(second_user.steam_uid)
        end
      end

      context "when the user is a territory admin" do
        before do
          make_territory_admin!(user)
          territory.revoke_membership(user.steam_uid)
        end

        it "allows them to add any player" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Target's add notification
          # 4: Requestor's confirmation
          # 5: Discord log
          wait_for { ESM::Test.messages.size }.to eq(5)

          expect(
            ESM::Test.messages.retrieve(/you've been added to `#{territory.encoded_id}` successfully/i)
          ).not_to be_nil
        end

        it "allows the user to add themselves" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: user.steam_uid
            }
          )

          # No request message is sent for oneself
          # 1: Success message
          # 2: Discord log
          wait_for { ESM::Test.messages.size }.to eq(2)

          expect(
            ESM::Test.messages.retrieve(/you've been added to `#{territory.encoded_id}` successfully/i)
          ).not_to be_nil
        end
      end

      context "when the target is a unregistered steam uid" do
        it "does not allow adding them" do
          second_user_steam_uid = second_user.steam_uid
          second_user.update!(steam_uid: "")

          expect {
            execute!(
              arguments: {
                server_id: server.server_id,
                territory_id: territory.encoded_id,
                target: second_user_steam_uid
              }
            )
          }.to raise_error do |error|
            expect(error.data.description).to match(/hey .+, .+ has not registered with me yet/i)
          end
        end
      end

      context "when the flag is null" do
        before { territory.delete_flag }

        it "returns the translated Add_NullFlag_Admin error" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          wait_for { ESM::Test.messages.size }.to eq(4)

          expect(
            ESM::Test.messages.retrieve(
              "Player attempted to add Target to territory, but the territory flag was not found in game"
            )
          ).not_to be_nil

          expect(
            ESM::Test.messages.retrieve(/i was unable to find a territory with the ID of `#{territory.encoded_id}`/i)
          ).not_to be_nil
        end
      end

      context "when the user is not a moderator or owner of the territory" do
        before { territory.revoke_membership(user.steam_uid) }

        it "returns the translated Add_MissingAccess error" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          wait_for { ESM::Test.messages.size }.to eq(4)

          expect(
            ESM::Test.messages.retrieve("Player attempted to add Target to territory, but Player does not have permission")
          ).not_to be_nil

          expect(
            ESM::Test.messages.retrieve("#{user.mention}, you do not have permission")
          ).not_to be_nil
        end
      end

      context "when the user attempts to add themselves to the territory without being a territory admin" do
        it "returns the translated Add_InvalidAdd error" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: user.steam_uid
            }
          )

          # No request message is sent for oneself
          # 1: Player failure message
          # 2: Discord log
          wait_for { ESM::Test.messages.size }.to eq(2)

          expect(
            ESM::Test.messages.retrieve("#{user.mention}, you cannot add yourself to this territory")
          ).not_to be_nil

          expect(
            ESM::Test.messages.retrieve("Player attempted to add themselves to the territory. Time to go laugh at them!")
          ).not_to be_nil
        end
      end

      context "when the target is already a member of the territory" do
        before do
          territory.build_rights << second_user.steam_uid
          territory.save!
        end

        it "returns the translated Add_ExistingRights error" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.retrieve("#{user.mention}, this Player already has build rights")
          ).not_to be_nil
        end
      end

      context "when the player has not joined the server" do
        before { user.exile_account.destroy! }

        it "raises PlayerNeedsToJoin" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.retrieve("need to join")
          ).not_to be_nil
        end
      end

      context "when the target has not joined the server" do
        before { second_user.exile_account.destroy! }

        it "raises TargetNeedsToJoin" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          wait_for { ESM::Test.messages.size }.to eq(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.retrieve("needs to join")
          ).not_to be_nil
        end
      end
    end
  end
end
