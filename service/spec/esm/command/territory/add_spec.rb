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
            embed = error.to_embed
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
            expect(error.to_embed.description).to match(/hey #{user.mention}, #{steam_uid} has not registered with me yet/i)
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

          ESM.discord_bot.test_outbox.await_size(2)

          embed = ESM.discord_bot.test_outbox.first.content

          # Checks for requestors message
          expect(embed).not_to be_nil

          # Checks for requestees message
          expect(ESM.discord_bot.test_outbox.size).to eq(2)

          # Process the request
          request = previous_command.request
          expect(request).not_to be_nil

          # Reset before responding. With the synchronous V1 fake the response
          # round-trip completes and queues follow-up deliveries immediately,
          # so clearing AFTER respond would race the delivery_overseer.
          ESM.discord_bot.test_outbox.clear

          # Respond to the request
          request.accept!

          # Wait for the server to respond
          ESM.discord_bot.test_outbox.await_size(2)

          expect(ESM.discord_bot.test_outbox.size).to eq(2)
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

          # An admin adding themselves skips the request and goes straight to the
          # server, so the synchronous V1 fake delivers the response during execute!.
          expect(ESM::Request.all.size).to eq(0)

          ESM.discord_bot.test_outbox.await_size(1)

          embed = ESM.discord_bot.test_outbox.first.content
          expect(embed.description).to match(/you've been added to/i)
        end
      end
    end
  end

  describe "V2", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", :requires_connection do
      include_context "connection"

      let!(:territory) do
        owner_uid = Faker::Steam.uid
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

          ESM.discord_bot.test_outbox.await_size(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Target's add notification
          # 4: Requestor's confirmation
          # 5: Discord log
          ESM.discord_bot.test_outbox.await_size(5)

          # The last messages are not always in order...
          # Requestee message
          expect(
            ESM.discord_bot.test_outbox.retrieve(/Welcome to #{territory.name}!/i)
          ).not_to be_nil

          # Requestor message
          expect(
            ESM.discord_bot.test_outbox.retrieve(
              /#{second_user.mention} has been added to territory `#{territory.encoded_id}`/
            )
          ).not_to be_nil

          # Admin log on the community's discord server
          log_message = ESM.discord_bot.test_outbox.retrieve("Player added Target to territory")
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
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          allow_any_instance_of(ESM::Community)
            .to receive(:territory_admin_users)
            .and_return(ESM::User.where(id: user.id))
        end

        it "allows them to add any player" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          ESM.discord_bot.test_outbox.await_size(1)  # We bypass request checks

          expect(
            ESM.discord_bot.test_outbox.retrieve(/you've been added to territory `#{territory.encoded_id}`/i)
          ).not_to be_nil
        end

        it "allows the user to add themselves" do
          territory.revoke_membership(user.steam_uid)

          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: user.steam_uid
            }
          )

          ESM.discord_bot.test_outbox.await_size(1) # We bypass request checks

          expect(
            ESM.discord_bot.test_outbox.retrieve(/you've been added to territory `#{territory.encoded_id}`/i)
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
            expect(error.to_embed.description).to match(/hey .+, .+ has not registered with me yet/i)
          end
        end
      end

      context "when the flag is null" do
        before { territory.delete_flag }

        it "returns the translated NullFlag error" do
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
          ESM.discord_bot.test_outbox.await_size(4)

          expect(
            ESM.discord_bot.test_outbox.retrieve("territory flag was not found in game")
          ).not_to be_nil

          expect(
            ESM.discord_bot.test_outbox.retrieve(/i was unable to find a territory with the ID of `#{territory.encoded_id}`/i)
          ).not_to be_nil
        end
      end

      context "when the user is not a moderator or owner of the territory" do
        before { territory.revoke_membership(user.steam_uid) }

        it "returns the translated MissingTerritoryAccess error" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          ESM.discord_bot.test_outbox.await_size(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          ESM.discord_bot.test_outbox.await_size(4)

          expect(
            ESM.discord_bot.test_outbox.retrieve("Player attempted to perform an action on Territory but they do not have access")
          ).not_to be_nil

          expect(
            ESM.discord_bot.test_outbox.retrieve("#{user.mention}, you do not have permission")
          ).not_to be_nil
        end
      end

      context "when the user attempts to add themselves to the territory without being a territory admin" do
        it "returns the translated Add_CannotAddSelf error" do
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
          ESM.discord_bot.test_outbox.await_size(1)

          expect(
            ESM.discord_bot.test_outbox.retrieve("#{user.mention}, you cannot add yourself to this territory")
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

          ESM.discord_bot.test_outbox.await_size(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          ESM.discord_bot.test_outbox.await_size(3)

          expect(
            ESM.discord_bot.test_outbox.retrieve(
              "#{user.mention}, #{second_user.mention} already has build rights"
            )
          ).not_to be_nil
        end
      end

      context "when the user is a territory admin and the target is already a member of the territory" do
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          allow_any_instance_of(ESM::Community)
            .to receive(:territory_admin_users)
            .and_return(ESM::User.where(id: user.id))

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

          ESM.discord_bot.test_outbox.await_size(1) # We bypass request checks

          expect(
            ESM.discord_bot.test_outbox.retrieve(
              "#{user.mention}, #{second_user.mention} already has build rights"
            )
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

          ESM.discord_bot.test_outbox.await_size(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          ESM.discord_bot.test_outbox.await_size(3)

          expect(
            ESM.discord_bot.test_outbox.retrieve("need to join")
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

          ESM.discord_bot.test_outbox.await_size(2)

          accept_request

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          ESM.discord_bot.test_outbox.await_size(3)

          expect(
            ESM.discord_bot.test_outbox.retrieve("needs to join")
          ).not_to be_nil
        end
      end
    end
  end

  describe "#on_website_execute", requires_connection: true do
    include_context "command"
    include_context "connection"

    let!(:territory) do
      owner_uid = Faker::Steam.uid
      create(
        :exile_territory,
        owner_uid: owner_uid,
        moderators: [owner_uid, user.steam_uid],
        build_rights: [owner_uid, user.steam_uid],
        server_id: server.id
      )
    end

    subject(:server_command) do
      execute_website!(
        arguments: {
          server_id: server.server_id,
          territory_id: territory.encoded_id,
          target: second_user.steam_uid
        }
      )
    end

    before do
      user.exile_account
      second_user.exile_account

      territory.create_flag
    end

    context "when a moderator adds another player" do
      it "creates a request for the target with a null (web) origin" do
        expect { server_command }.to change(ESM::Request, :count).by(1)

        request = ESM::Request.last
        expect(request.requestor).to eq(user)
        expect(request.requestee).to eq(second_user)
        expect(request.requested_from_channel_id).to be_nil
      end

      it "notifies only the target on Discord, leaving the requestor's confirmation to the website" do
        server_command

        # The target receives the request through the Discord notify layer...
        ESM.discord_bot.test_outbox.await_size(1)

        # ...but the "request sent" confirmation is suppressed on the website path.
        expect(ESM.discord_bot.test_outbox.size).to eq(1)
      end

      it "records the requested outcome on the row" do
        expect(server_command.result.with_indifferent_access[:outcome].to_s).to eq("requested")
      end
    end

    context "when a territory admin adds a player" do
      before do
        allow_any_instance_of(ESM::Community)
          .to receive(:territory_admin_users).and_return(ESM::User.where(id: user.id))
      end

      it "adds the player immediately, records the added outcome, and skips the request" do
        expect { server_command }.not_to change(ESM::Request, :count)

        expect(server_command.result.with_indifferent_access[:outcome].to_s).to eq("added")
        expect(territory.reload.build_rights).to include(second_user.steam_uid)
      end
    end

    context "when the web request is accepted" do
      it "delivers the outcome to the requestor's DM instead of crashing on the null channel" do
        server_command
        request = ESM::Request.last

        ESM.discord_bot.test_outbox.clear

        # Pre-fix, on_accept built a Discord origin with the request's null channel, so the
        # requestor reply had nowhere to land and blew up. It now resolves to the requestor's DM.
        expect { request.accept! }.not_to raise_error

        # The target is welcomed to the territory...
        expect(
          ESM.discord_bot.test_outbox.retrieve(/Welcome to #{territory.name}!/i)
        ).not_to be_nil

        # ...and the requestor's confirmation lands rather than raising on a null channel.
        expect(
          ESM.discord_bot.test_outbox.retrieve(/#{second_user.mention} has been added to territory `#{territory.encoded_id}`/)
        ).not_to be_nil
      end
    end
  end
end
