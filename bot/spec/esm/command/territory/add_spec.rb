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
    describe "#on_execute/#on_response", :requires_connection do
      include_context "connection"

      let(:territory) do
        owner_uid = ESM::Test.steam_uid
        create(
          :exile_territory,
          owner_uid: owner_uid,
          moderators: [owner_uid, user.steam_uid],
          build_rights: [owner_uid, user.steam_uid],
          server_id: server.id
        )
      end

      it "adds the user and logs to Discord" do
        execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid})

        # Initial request and the notice
        wait_for { ESM::Test.messages.size }.to eq(2)

        # Process the request
        request = previous_command.request
        expect(request).not_to be_nil

        # Respond to the request
        request.respond(true)

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

      it "adds a user via territory admin override", :territory_admin_bypass do
        # The user and target user are not members of this territory.
        # However, user is a territory admin
        territory.revoke_membership(user.steam_uid)

        execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid})
        wait_for { ESM::Test.messages.size }.to eq(2)

        # 1: Request
        # 2: Request notice
        # 3: Target's add notification
        # 4: Requestor's confirmation
        # 5: Discord log
        expect(previous_command.request&.respond(true)).to be_truthy
        wait_for { ESM::Test.messages.size }.to eq(5)

        expect(
          ESM::Test.messages.retrieve(/you've been added to `#{territory.encoded_id}` successfully/i)
        ).not_to be_nil
      end

      it "adds self via territory admin override", :territory_admin_bypass do
        # The user and target user are not members of this territory.
        # However, user is a territory admin
        territory.revoke_membership(user.steam_uid)

        execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: user.steam_uid})

        # No request message is sent for oneself
        # 1: Success message
        # 2: Discord log
        wait_for { ESM::Test.messages.size }.to eq(2)

        expect(
          ESM::Test.messages.retrieve(/you've been added to `#{territory.encoded_id}` successfully/i)
        ).not_to be_nil
      end

      it "does not allow adding a Steam UID that hasn't been registered with ESM" do
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

      describe "SQF Errors", :error_testing do
        it "handles NullFlag" do
          territory.delete_flag

          execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid})
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          expect(previous_command.request&.respond(true)).to be_truthy
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

        it "handles MissingAccess" do
          territory.revoke_membership(user.steam_uid)

          execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid})
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          expect(previous_command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(4)

          expect(
            ESM::Test.messages.retrieve("Player attempted to add Target to territory, but Player does not have permission")
          ).not_to be_nil

          expect(
            ESM::Test.messages.retrieve(
              "#{user.mention}, you do not have permission to add people to `#{territory.encoded_id}`"
            )
          ).not_to be_nil
        end

        it "handles InvalidAdd" do
          execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: user.steam_uid})

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

        it "handles InvalidAdd_Owner" do
          territory.owner_uid = second_user.steam_uid
          territory.save!

          execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid})
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          expect(previous_command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.retrieve(
              "#{user.mention}, the Target is the owner of this territory which automatically makes them a member of this territory, silly :stuck_out_tongue_winking_eye:"
            )
          ).not_to be_nil
        end

        it "handles InvalidAdd_Exists" do
          territory.build_rights << second_user.steam_uid
          territory.save!

          execute!(arguments: {server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid})
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          expect(previous_command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.retrieve("#{user.mention}, this Player already has build rights")
          ).not_to be_nil
        end
      end
    end
  end
end
