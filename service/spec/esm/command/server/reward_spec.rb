# frozen_string_literal: true

describe ESM::Command::Server::Reward, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is a player command" do
    expect(command.type).to eq(:player)
  end

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when there are rewards" do
        it "gives them to the player and returns a message" do
          execute!(arguments: {server_id: server.server_id})
          ESM.discord_bot.test_outbox.await_size(2)

          embed = ESM.discord_bot.test_outbox.first.content

          # Checks for requestors message
          expect(embed).not_to be_nil

          # Process the request
          request = previous_command.request
          expect(request).not_to be_nil

          # So we can track the response
          ESM.discord_bot.test_outbox.clear

          # Respond to the request
          request.accept!

          # Wait for the server to respond
          wait_for { connection.requests }.to be_blank
          ESM.discord_bot.test_outbox.await_size(1)

          embed = ESM.discord_bot.test_outbox.first.content
          reward = server.server_rewards.default.first

          expect(embed.description).to include("#{reward.player_poptabs}x Poptabs (Player)") if reward.player_poptabs.positive?
          expect(embed.description).to include("#{reward.locker_poptabs}x Poptabs (Locker)") if reward.locker_poptabs.positive?
          expect(embed.description).to include("#{reward.respect}x Respect") if reward.respect.positive?

          reward.reward_items.each do |item, quantity|
            # Technically, the item should be converted to a proper display name by the server, but I don't have that ability here.
            expect(embed.description).to include("#{quantity}x #{item}")
          end
        end
      end

      context "when the user already has a request" do
        it "raises an exception" do
          execution_args = {arguments: {server_id: server.server_id}}

          # Create a pending request
          create(
            :request,
            requestor: user,
            requestee: user,
            requested_from_channel_id: community.discord_server.channels.first.id,
            command_name: command.command_name,
            command_arguments: execution_args[:arguments]
          )

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            embed = error.to_embed
            expect(embed.description).to match(/it appears you already have a request pending/i)
          end
        end
      end

      # A v1 server was handed its reward contents when it connected, so there is nothing here for a code to name.
      # Falling back to the default would hand them something other than what they asked for and say nothing about it.
      context "when a package is named by its code" do
        it "raises an exception" do
          create(:server_reward, server:, reward_id: "daily", player_poptabs: 100)

          execution_args = {arguments: {server_id: server.server_id, reward_id: "daily"}}

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            expect(error.to_embed.description).to match(/unable to find a reward with the ID of/i)
          end
        end
      end

      context "when there are no rewards configured" do
        it "raises an exception" do
          # Remove the default reward and create a blank one
          server.server_rewards.default.first.delete
          server.send(:create_default_reward)

          execution_args = {arguments: {server_id: server.server_id}}
          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            embed = error.to_embed
            expect(embed.description).to match(/the selected reward package is not available at this tim/i)
          end
        end
      end

      # A v1 server has no packages, so the command's own unscoped cooldown is both the one checked and the one written
      describe "cooldowns" do
        let(:cooldown_quantity) { 1 }
        let(:cooldown_type) { "days" }
        let(:reward_cooldown) { ESM::Cooldown.find_by(command_name: "reward", scope_key: nil) }

        before do
          create(:command_configuration, community:, command_name: "reward", cooldown_quantity:, cooldown_type:)
        end

        def redeem!
          ESM.discord_bot.test_outbox.clear

          execute!(arguments: {server_id: server.server_id})
          ESM.discord_bot.test_outbox.await_size(2)

          ESM.discord_bot.test_outbox.clear
          previous_command.request.accept!

          # The receipt is sent after the cooldown is written, so it arriving means the row is there to read
          wait_for { connection.requests }.to be_blank
          ESM.discord_bot.test_outbox.await_size(1)
        end

        def expect_refusal(message)
          expect { execute!(arguments: {server_id: server.server_id}) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            expect(error.to_embed.description).to match(message)
          end
        end

        it "starts the command's cooldown once the server has delivered" do
          redeem!

          expect(reward_cooldown).to be_present
          expect(reward_cooldown.cooldown_type).to eq("days")
          expect(reward_cooldown.cooldown_quantity).to eq(1)
          expect(reward_cooldown.expires_at).to be_within(1.minute).of(1.day.from_now)
          expect(reward_cooldown).to be_active
        end

        it "refuses another redemption while the cooldown is running" do
          redeem!

          expect_refusal("you're on cooldown")
        end

        it "lets them redeem again once the cooldown is reset" do
          redeem!

          # What reset_cooldown does to every row it selects
          reward_cooldown.reset!

          expect { redeem! }.not_to raise_error
          expect(reward_cooldown.reload).to be_active
        end

        it "is not held back by a package's cooldown" do
          create(
            :cooldown, :active,
            steam_uid: user.steam_uid,
            community_id: community.id,
            server_id: server.id,
            command_name: "reward",
            scope_key: "default"
          )

          expect { redeem! }.not_to raise_error
        end

        context "when the cooldown counts uses" do
          let(:cooldown_quantity) { 2 }
          let(:cooldown_type) { "times" }

          it "allows as many redemptions as the allowance and then refuses" do
            redeem!
            expect(reward_cooldown.cooldown_amount).to eq(1)

            redeem!
            expect(reward_cooldown.reload.cooldown_amount).to eq(2)

            expect_refusal("exceeded the amount of times")
          end

          it "counts again from zero after a reset" do
            2.times { redeem! }

            reward_cooldown.reset!
            redeem!

            expect(reward_cooldown.reload.cooldown_amount).to eq(1)
          end
        end
      end
    end
  end

  describe "V2", v2: true do
    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let(:number_of_messages) { 3 }
      let(:vehicle_class) { "Exile_Car_Hatchback_Rusty1" }
      let(:claim) { ESM::ServerRewardClaim.find_by(user_id: user.id, server_id: server.id) }

      subject(:execute_command) do
        result = execute!(arguments: {server_id: server.server_id})

        ESM.discord_bot.test_outbox.await_size(2)

        accept_request

        ESM.discord_bot.test_outbox.await_size(number_of_messages)

        result
      end

      # What the player is wearing when they spawn, which decides whether reward items fit on them or end up in a
      # holder at their feet. It has to be on the exile_player row before the spawn, since the harness builds the
      # player object by replaying that row.
      let(:player_loadout) { {} }

      before do
        user.exile_player.update!(**player_loadout) if player_loadout.any?

        spawn_player_for(user)

        # ExileClientPlayerScore is a single global. The test player is a server-spawned bambi, so its owner is the
        # server and updateRespect's remoteExec lands in this namespace, where it outlives the example that set it.
        execute_sqf!("ExileClientPlayerScore = nil; true")
      end

      # Driven end to end rather than from seeded rows: a package is redeemed, and the next attempt meets whatever that
      # redemption wrote
      shared_context "reward cooldowns" do
        let!(:number_of_messages) { 4 }
        let(:package_cooldown_quantity) { 2 }
        let(:package_cooldown_type) { "hours" }
        let(:reward_cooldown) { ESM::Cooldown.find_by(command_name: "reward", scope_key: "default") }

        before do
          server.server_rewards.default.first.update!(
            reward_items: {},
            reward_vehicles: [],
            player_poptabs: 10,
            locker_poptabs: 0,
            respect: 0,
            cooldown_quantity: package_cooldown_quantity,
            cooldown_type: package_cooldown_type
          )
        end

        def redeem!(**arguments)
          ESM.discord_bot.test_outbox.clear

          execute!(arguments: {server_id: server.server_id, **arguments})
          ESM.discord_bot.test_outbox.await_size(2)

          accept_request
          ESM.discord_bot.test_outbox.await_size(number_of_messages)
        end

        def expect_refusal(message, channel_type: :text)
          expect {
            execute!(channel_type:, arguments: {server_id: server.server_id})
          }.to raise_error(ESM::Exception::CheckFailure) do |error|
            expect(error.to_embed.description).to match(message)
          end
        end
      end

      # Delivery is not all-or-nothing. Whatever the extension could not hand over comes back and is written onto the
      # claim so the player can try again, and the cooldown only starts once nothing is left owing.
      shared_context "settling the claim" do
        let!(:number_of_messages) { 4 }
        let(:reward_vehicles) { [] }
        let(:reward_items) { {} }
        let(:reward_cooldown) { ESM::Cooldown.find_by(scope_key: "default") }

        before do
          server.server_rewards.default.first.update!(
            reward_items:,
            reward_vehicles:,
            player_poptabs: 10,
            locker_poptabs: 0,
            respect: 0,
            cooldown_quantity: 2,
            cooldown_type: "hours"
          )
        end
      end

      ##########################################################################################################
      # Behavior every v2 server shares
      ##########################################################################################################
      context "on any v2 server" do
        context "when there are rewards" do
          let!(:number_of_messages) { 4 }

          let!(:reward_items) do
            {Exile_Weapon_AKM: 1, Exile_Magazine_30Rnd_762x39_AK: 3}
          end

          let!(:player_poptabs) { 10 }
          let!(:locker_poptabs) { 20 }
          let!(:respect) { 30 }

          let!(:expected_reward_items) do
            <<~STRING.strip
              - 10x Poptabs added to your player
              - 20x Poptabs added to your locker
              - 30x Respect
              - 3x 7.62 mm 30Rnd Mag
              - 1x AKM 7.62 mm
            STRING
          end

          before do
            # The server factory seeds the package with faker vehicles, which a newer server would leave on a claim
            server.server_rewards.default.first.update!(
              reward_items:,
              reward_vehicles: [],
              player_poptabs:,
              locker_poptabs:,
              respect:
            )
          end

          it "gifts them to the player" do
            execute_command

            # Admin message
            embed = ESM.discord_bot.test_outbox.retrieve("Player received the following")&.content

            expect(embed).not_to be(nil)
            expect(embed.description).to match(expected_reward_items)

            # Player message
            embed = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

            expect(embed).not_to be(nil)
            expect(embed.description).to match(expected_reward_items)

            # Poptabs on the player object and in the player row. setPlayerMoney keys off ExileDatabaseID, so this is
            # also what a corrupted ID would take down - see the immutability example below.
            wait_for { get_player_variable!(user.net_id, "ExileMoney", -1) }.to eq(player_poptabs)
            expect(user.exile_player.reload.money).to eq(player_poptabs)

            expect_locker_to_eq(user, locker_poptabs)

            # ExileScore is not broadcast: it reaches the client through updateRespect's remoteExec, so it is read
            # once rather than polled
            expect(get_player_variable!(user.net_id, "ExileScore", -1)).to eq(respect)
            expect(user.exile_account.reload.score).to eq(respect)
            expect(execute_sqf!(%(missionNamespace getVariable ["ExileClientPlayerScore", -1]))).to eq(respect)

            # Every rewarded item reaches the player one way or the other: onto them if it fits, into a holder at
            # their feet if it does not
            delivered = get_player_cargo!(user.net_id) + nearby_loot_holders!(user.net_id).flatten

            expect(delivered.tally).to include(
              "Exile_Weapon_AKM" => 1,
              "Exile_Magazine_30Rnd_762x39_AK" => 3
            )

            # Nothing was held back, so the package is spent
            expect(claim).to be_nil
          end

          include_examples "arma_exile_db_id_immutable" do
            let(:net_id) { user.net_id }
          end
        end

        context "when the player has room to carry the reward" do
          let!(:player_loadout) { {uniform: "Exile_Uniform_BambiOverall"} }
          let!(:reward_items) { {Exile_Magazine_30Rnd_762x39_AK: 1} }

          before do
            server.server_rewards.default.first.update!(
              reward_items:,
              reward_vehicles: [],
              player_poptabs: 0,
              locker_poptabs: 0,
              respect: 0
            )
          end

          it "puts the items on the player and drops nothing" do
            execute_command

            expect(get_player_cargo!(user.net_id)).to include("Exile_Magazine_30Rnd_762x39_AK")
            expect(nearby_loot_holders!(user.net_id).flatten).to be_empty
          end
        end

        context "when the player has nowhere to put the reward" do
          # No uniform, vest or backpack, which is what an exile_player row carries by default
          let!(:reward_items) { {Exile_Magazine_30Rnd_762x39_AK: 3} }

          before do
            server.server_rewards.default.first.update!(
              reward_items:,
              reward_vehicles: [],
              player_poptabs: 0,
              locker_poptabs: 0,
              respect: 0
            )
          end

          it "spawns a holder at their feet and fills it with the items" do
            execute_command

            expect(get_player_cargo!(user.net_id)).to be_empty

            holders = nearby_loot_holders!(user.net_id)

            expect(holders.size).to eq(1)
            expect(holders.first).to eq(["Exile_Magazine_30Rnd_762x39_AK"] * 3)
          end
        end

        context "when a reward item is not a real classname" do
          let!(:number_of_messages) { 5 }
          let!(:reward_items) { {Exile_Magazine_30Rnd_762x39_AK: 2, NotAThingAnyoneOwns: 1} }

          before do
            server.server_rewards.default.first.update!(
              reward_items:,
              reward_vehicles: [],
              player_poptabs: 0,
              locker_poptabs: 0,
              respect: 0
            )
          end

          it "logs the invalid item and still delivers the rest" do
            execute_command

            expect(
              ESM.discord_bot.test_outbox.retrieve("Invalid Reward Item")
            ).not_to be(nil)

            delivered = get_player_cargo!(user.net_id) + nearby_loot_holders!(user.net_id).flatten

            expect(delivered.tally).to include("Exile_Magazine_30Rnd_762x39_AK" => 2)
            expect(delivered).not_to include("NotAThingAnyoneOwns")

            # A classname the server does not have cannot be retried into existence, so it is not kept on a claim
            expect(claim).to be_nil
          end
        end

        context "when there are no rewards" do
          before do
            # The server factory seeds a reward with faker vehicles, so an empty package has to clear those too
            server.server_rewards.default.first.update!(
              reward_items: [],
              reward_vehicles: [],
              player_poptabs: 0,
              locker_poptabs: 0,
              respect: 0
            )
          end

          include_examples "raises_check_failure" do
            let!(:matcher) { "the selected reward package is not available at this time" }
          end
        end

        context "when the package is on cooldown" do
          before do
            # Reward requires registration, so its cooldowns key on steam_uid rather than user_id
            create(
              :cooldown, :active,
              steam_uid: user.steam_uid,
              community_id: community.id,
              server_id: server.id,
              command_name: "reward",
              scope_key: "default"
            )
          end

          include_examples "raises_check_failure" do
            let!(:matcher) { "you're on cooldown" }
          end
        end

        context "when choosing a reward package by id" do
          let!(:number_of_messages) { 4 }

          let!(:named_reward) do
            create(
              :server_reward,
              server_id: server.id,
              reward_id: "daily",
              reward_items: {},
              reward_vehicles: [],
              player_poptabs: 55,
              locker_poptabs: 0,
              respect: 0,
              cooldown_quantity: 1,
              cooldown_type: "days"
            )
          end

          before do
            server.server_rewards.default.first.update!(
              reward_items: {},
              reward_vehicles: [],
              player_poptabs: 10,
              locker_poptabs: 0,
              respect: 0
            )
          end

          it "delivers that package instead of the default" do
            execute!(arguments: {server_id: server.server_id, reward_id: "daily"})
            ESM.discord_bot.test_outbox.await_size(2)

            accept_request
            ESM.discord_bot.test_outbox.await_size(number_of_messages)

            embed = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

            expect(embed).not_to be(nil)
            expect(embed.description).to match("55x")
            expect(embed.description).not_to match("10x")
          end

          it "scopes the cooldown to that package, leaving the default claimable" do
            execute!(arguments: {server_id: server.server_id, reward_id: "daily"})
            ESM.discord_bot.test_outbox.await_size(2)

            accept_request
            ESM.discord_bot.test_outbox.await_size(number_of_messages)

            expect(ESM::Cooldown.find_by(scope_key: "daily")).to be_present
            expect(ESM::Cooldown.find_by(scope_key: "default")).to be_nil
          end

          # execute_command hardcodes its arguments, so this one drives execute! directly
          context "and no package has that id" do
            it "is expected to raise CheckFailure" do
              expect {
                execute!(arguments: {server_id: server.server_id, reward_id: "does_not_exist"})
              }.to raise_error(ESM::Exception::CheckFailure) do |error|
                expect(error.to_embed.description).to match("unable to find a reward with the ID")
              end
            end
          end
        end

        # The enabled filter used to live only in the website's package list, so a disabled package was still
        # redeemable by typing its code
        context "when the package is disabled" do
          before do
            server.server_rewards.default.first.update!(enabled: false)

            create(
              :server_reward,
              server_id: server.id,
              reward_id: "daily",
              reward_items: {},
              reward_vehicles: [],
              player_poptabs: 55,
              locker_poptabs: 0,
              respect: 0,
              enabled: false
            )
          end

          it "refuses it by code and as the default" do
            expect {
              execute!(arguments: {server_id: server.server_id, reward_id: "daily"})
            }.to raise_error(ESM::Exception::CheckFailure) do |error|
              expect(error.to_embed.description).to match("unable to find a reward with the ID of `daily`")
            end

            expect {
              execute!(arguments: {server_id: server.server_id})
            }.to raise_error(ESM::Exception::CheckFailure) do |error|
              expect(error.to_embed.description).to match("unable to find a reward with the ID of `default`")
            end
          end
        end

        context "when there is an existing request" do
          before do
            # Executing the command but not handling the request will cause the request to be pending
            execute!(arguments: {server_id: server.server_id})

            # Reward skips the lifecycle cooldown and only writes a reward-scoped one once a request is accepted, so
            # there is usually nothing here to reset
            previous_command.current_cooldown&.reset!
          end

          include_examples "raises_check_failure" do
            let!(:matcher) { "it appears you already have a request pending" }
          end
        end

        context "when the player has not joined the server" do
          before do
            user.exile_account.destroy!
          end

          it "is expected to raise PlayerNeedsToJoin" do
            execute_command

            embed = latest_message
            expect(embed.description).to match("need to join")
          end

          # Nothing was handed over, so nothing is owed. A claim left behind here is one the player can never deliver,
          # on every server they have never joined.
          it "leaves no claim behind" do
            execute_command

            expect(claim).to be_nil
          end

          context "and they already had a claim waiting" do
            let!(:pending_claim) do
              ESM::ServerRewardClaim.create!(
                server_id: server.id,
                user_id: user.id,
                player_poptabs: 25,
                locker_poptabs: 0,
                respect: 0,
                items: {},
                vehicles: [],
                state: :waiting
              )
            end

            it "keeps what they are owed and leaves it deliverable" do
              execute_command

              expect(claim).to be_present
              expect(claim.player_poptabs).to eq(25)
              expect(claim).to be_waiting
            end
          end
        end

        context "when a delivery is already running" do
          let!(:pending_claim) do
            ESM::ServerRewardClaim.create!(
              server_id: server.id,
              user_id: user.id,
              player_poptabs: 25,
              locker_poptabs: 0,
              respect: 0,
              items: {},
              vehicles: [],
              state: :in_flight
            )
          end

          it "refuses a second one rather than delivering twice" do
            expect {
              execute!(arguments: {server_id: server.server_id})
            }.to raise_error(ESM::Exception::CheckFailure) do |error|
              expect(error.to_embed.description).to match("being delivered right now")
            end

            expect(claim.reload).to be_in_flight
            expect(claim.player_poptabs).to eq(25)
          end
        end

        context "when logging is enabled" do
          let!(:number_of_messages) { 4 }

          before do
            server.server_setting.update!(logging_reward_player: true)
          end

          include_examples "arma_discord_logging_enabled" do
            let(:message) { "`ESMs_command_reward` executed successfully" }
            let(:fields) { [player_field] }
          end
        end

        context "when logging is disabled" do
          before do
            server.server_setting.update!(logging_reward_player: false)
          end

          include_examples "arma_discord_logging_disabled" do
            let(:message) { "`ESMs_command_reward` executed successfully" }
          end
        end

        describe "cooldowns" do
          include_context "reward cooldowns"

          it "starts the package's cooldown once it is delivered" do
            redeem!

            expect(reward_cooldown).to be_present
            expect(reward_cooldown.cooldown_type).to eq("hours")
            expect(reward_cooldown.cooldown_quantity).to eq(2)
            expect(reward_cooldown.expires_at).to be_within(1.minute).of(2.hours.from_now)
            expect(reward_cooldown).to be_active
          end

          it "refuses the same package while its cooldown is running" do
            redeem!

            expect_refusal("you're on cooldown")
          end

          # A DM has no community of its own, so the cooldown has to be found through the server's
          it "refuses it from a DM as well" do
            redeem!

            expect_refusal("you're on cooldown", channel_type: :pm)
          end

          it "leaves a different package claimable" do
            create(
              :server_reward,
              server_id: server.id,
              reward_id: "daily",
              reward_items: {},
              reward_vehicles: [],
              player_poptabs: 55,
              locker_poptabs: 0,
              respect: 0
            )

            redeem!

            expect { redeem!(reward_id: "daily") }.not_to raise_error
            expect(ESM::Cooldown.where(command_name: "reward").pluck(:scope_key)).to contain_exactly("default", "daily")
          end

          it "lets them claim again once the cooldown is reset" do
            redeem!

            # What reset_cooldown does to every row it selects
            reward_cooldown.reset!

            expect { redeem! }.not_to raise_error
            expect(reward_cooldown.reload).to be_active
          end

          it "lets them claim again once the cooldown has expired" do
            redeem!

            reward_cooldown.update!(expires_at: 1.minute.ago)

            expect { redeem! }.not_to raise_error
          end

          # The shape a community is most likely to have: no cooldown on the package, and a use allowance on the
          # command
          context "when the package falls back to a cooldown that counts uses" do
            let(:package_cooldown_quantity) { nil }
            let(:package_cooldown_type) { nil }

            before do
              create(
                :command_configuration,
                community:,
                command_name: "reward",
                cooldown_quantity: 2,
                cooldown_type: "times"
              )
            end

            it "allows as many redemptions as the allowance and then refuses" do
              redeem!
              expect(reward_cooldown.cooldown_amount).to eq(1)
              expect(reward_cooldown).not_to be_active

              redeem!
              expect(reward_cooldown.reload.cooldown_amount).to eq(2)

              expect_refusal("exceeded the amount of times")
            end

            it "counts again from zero after a reset" do
              2.times { redeem! }

              reward_cooldown.reset!
              redeem!

              expect(reward_cooldown.reload.cooldown_amount).to eq(1)
            end
          end
        end

        describe "settling the claim" do
          include_context "settling the claim"

          context "when everything is delivered" do
            it "drops the claim and starts the cooldown" do
              execute_command

              expect(claim).to be_nil

              expect(reward_cooldown).to be_present
              expect(reward_cooldown.cooldown_type).to eq("hours")
              expect(reward_cooldown.cooldown_quantity).to eq(2)
            end
          end

          context "when the package sets no cooldown of its own" do
            before do
              create(
                :command_configuration,
                community: community,
                command_name: "reward",
                cooldown_quantity: 12,
                cooldown_type: "hours"
              )

              server.server_rewards.default.first.update!(cooldown_quantity: nil, cooldown_type: nil)
            end

            it "falls back to the community's configuration for the command" do
              execute_command

              expect(claim).to be_nil

              expect(reward_cooldown).to be_present
              expect(reward_cooldown.cooldown_type).to eq("hours")
              expect(reward_cooldown.cooldown_quantity).to eq(12)
            end
          end

          context "when the player already has a claim waiting" do
            let(:claim_server) { server }

            let!(:pending_claim) do
              ESM::ServerRewardClaim.create!(
                server_id: claim_server.id,
                user_id: user.id,
                player_poptabs: 25,
                locker_poptabs: 0,
                respect: 0,
                items: {},
                vehicles: [],
                state: :waiting
              )
            end

            it "delivers what is owed rather than issuing the package again" do
              execute_command

              embed = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

              expect(embed).not_to be(nil)
              expect(embed.description).to match("25x")

              # The package's own 10 poptabs must not ride along with the claim
              expect(embed.description).not_to match("10x")

              expect(claim).to be_nil
            end

            # This claim names no package, which is the shape an admin building one by hand leaves behind. The player
            # redeemed nothing, so finishing it must not spend a cooldown they never started.
            it "puts nothing on cooldown" do
              execute_command

              expect(claim).to be_nil
              expect(ESM::Cooldown.where(command_name: "reward")).to be_empty
            end

            it "says the pending claim is what they are confirming" do
              execute!(arguments: {server_id: server.server_id})
              ESM.discord_bot.test_outbox.await_size(2)

              embed = ESM.discord_bot.test_outbox.retrieve("pending rewards")&.content

              expect(embed).not_to be(nil)
              expect(embed.description).to match("25")
            end

            context "and the reward package is on cooldown" do
              before do
                create(
                  :cooldown, :active,
                  steam_uid: user.steam_uid,
                  community_id: community.id,
                  server_id: server.id,
                  command_name: "reward",
                  scope_key: "default"
                )
              end

              # The cooldown gates issuing a new package. Finishing one the player is already owed is not issuing.
              it "still delivers it" do
                execute_command

                embed = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

                expect(embed).not_to be(nil)
                expect(claim).to be_nil
              end
            end

            context "and the claim belongs to a different server" do
              let(:claim_server) { create(:server, community_id: community.id) }

              it "is ignored and the package is issued for this server" do
                execute_command

                embed = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

                expect(embed).not_to be(nil)
                expect(embed.description).to match("10x")
                expect(embed.description).not_to match("25x")

                # The other server still owes them
                expect(pending_claim.reload).to be_present
              end
            end
          end
        end
      end

      ##########################################################################################################
      # 2.0.x: no vehicles, and a delivery that reports only a receipt, so nothing can come back undelivered
      ##########################################################################################################
      context "on a 2.0 server", server_version: "2.0" do
        context "when the player is not alive on the server" do
          before do
            user.kill_player!(server)
          end

          it "is expected to raise AlivePlayer" do
            execute_command

            expect(latest_message.description).to match("must be alive")
          end
        end

        context "when the package only holds vehicles" do
          before do
            server.server_rewards.default.first.update!(
              reward_items: [],
              reward_vehicles: [{class_name: vehicle_class, spawn_location: "nearby"}],
              player_poptabs: 0,
              locker_poptabs: 0,
              respect: 0
            )
          end

          include_examples "raises_check_failure" do
            let!(:matcher) { "the selected reward package is not available at this time" }
          end
        end

        # Which package a player picked is settled entirely bot-side; the extension only ever receives the contents.
        # Gating it on the version meant a named package silently became the default one, and the player was then told
        # the default's cooldown stood in their way.
        context "when choosing a reward package by id" do
          before do
            create(
              :server_reward,
              server_id: server.id,
              reward_id: "daily",
              reward_items: {},
              reward_vehicles: [],
              player_poptabs: 55,
              locker_poptabs: 0,
              respect: 0,
              cooldown_quantity: 1,
              cooldown_type: "days"
            )
          end

          it "honors the package" do
            execute!(arguments: {server_id: server.server_id, reward_id: "daily"})
            ESM.discord_bot.test_outbox.await_size(2)

            accept_request

            expect(ESM::Cooldown.where(command_name: "reward").pluck(:scope_key)).to eq(["daily"])
          end
        end

        describe "settling the claim" do
          include_context "settling the claim"

          context "when the package also holds a vehicle" do
            let(:reward_items) { {Exile_Magazine_30Rnd_762x39_AK: 1} }
            let(:reward_vehicles) { [{class_name: vehicle_class, spawn_location: "nearby"}] }

            it "delivers the rest without the vehicle and starts the cooldown" do
              execute_command

              # The request never promises a vehicle the server was not going to be sent
              request = ESM.discord_bot.test_outbox.retrieve("Before we get to the good stuff")&.content

              expect(request).not_to be(nil)
              expect(request.description).to include("**Pocket:**")
              expect(request.description).to include("**Items:**")
              expect(request.description).not_to include("**Vehicles:**")

              receipt = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

              expect(receipt).not_to be(nil)
              expect(receipt.description).to include("10x Poptabs added to your player")
              expect(receipt.description).to include("1x 7.62 mm 30Rnd Mag")
              expect(receipt.description).not_to include("Hatchback")

              wait_for { get_player_variable!(user.net_id, "ExileMoney", -1) }.to eq(10)

              expect(claim).to be_nil
              expect(reward_cooldown).to be_present
            end
          end
        end
      end

      ##########################################################################################################
      # 2.1+: vehicles, and a delivery that reports what it could not hand over
      ##########################################################################################################
      context "on a 2.1 or newer server", server_version: ">= 2.1" do
        context "when the player is not alive on the server" do
          before do
            user.kill_player!(server)
          end

          it "is expected to raise AlivePlayer" do
            execute_command

            expect(latest_message.description).to match("in game and alive")
          end
        end

        # The website refuses servers older than 2.1, so only a newer one can have been redeemed there
        describe "cooldowns" do
          include_context "reward cooldowns"

          it "refuses on Discord after the package was redeemed on the website" do
            execute_website!(arguments: {server_id: server.server_id, community_id: community.community_id})

            expect(reward_cooldown).to be_active
            expect_refusal("you're on cooldown")
          end
        end

        describe "settling the claim" do
          include_context "settling the claim"

          context "when a vehicle needs a spawn location only the website can ask for" do
            let(:reward_vehicles) do
              [{class_name: vehicle_class, spawn_location: "player_decides"}]
            end

            it "keeps the vehicle on the claim and does not start the cooldown" do
              execute_command

              expect(claim).to be_present
              expect(claim.vehicles.first[:class_name]).to eq(vehicle_class)

              # The poptabs landed, so they must not be owed a second time
              expect(claim.player_poptabs).to eq(0)

              expect(claim.attempt_count).to eq(1)
              expect(claim.last_attempt_at).to be_present
              failure = claim.state_details[:failures].first

              expect(failure[:bucket]).to eq("vehicles")
              expect(failure[:name]).to eq("Hatchback")
              expect(failure[:reason]).to match("website")

              # They still have an unfinished claim, so nothing should be gating a retry
              expect(reward_cooldown).to be_nil
            end

            it "tells the player what is still owed" do
              execute_command

              embed = ESM.discord_bot.test_outbox.retrieve("Partially Delivered")&.content

              expect(embed).not_to be(nil)
              expect(embed.description).to match("Hatchback")
            end
          end

          context "when a claim fails a second time" do
            let(:reward_vehicles) do
              [{class_name: vehicle_class, spawn_location: "player_decides"}]
            end

            it "counts the attempt and keeps what is still owed" do
              execute_command

              expect(claim.attempt_count).to eq(1)

              # A second run finds the waiting claim rather than reissuing the package
              execute!(arguments: {server_id: server.server_id})
              ESM.discord_bot.test_outbox.await_size(2)

              accept_request
              ESM.discord_bot.test_outbox.await_size(number_of_messages)

              claim.reload

              expect(claim.attempt_count).to eq(2)
              expect(claim.vehicles.first[:class_name]).to eq(vehicle_class)
              expect(claim.player_poptabs).to eq(0)
              expect(claim).to be_waiting
            end
          end

          # A claim does not remember the package it came from, so settling one falls back to the default package for
          # the cooldown's scope key. The retry that finishes a named package therefore leaves that package uncooled
          # and writes a cooldown against "default" instead, which the player never redeemed.
          context "when a claim from a named package is finished on a retry" do
            let!(:named_reward) do
              create(
                :server_reward,
                server_id: server.id,
                reward_id: "daily",
                reward_items: {},
                reward_vehicles: [{class_name: vehicle_class, spawn_location: "player_decides"}],
                player_poptabs: 55,
                locker_poptabs: 0,
                respect: 0,
                cooldown_quantity: 1,
                cooldown_type: "days"
              )
            end

            it "scopes the cooldown to the package the claim came from" do
              execute!(arguments: {server_id: server.server_id, reward_id: "daily"})
              ESM.discord_bot.test_outbox.await_size(2)

              accept_request

              expect(claim).to be_present
              expect(ESM::Cooldown.where(command_name: "reward")).to be_empty

              # Stands in for the website settling the vehicle the player had to decide on, leaving poptabs still owed
              claim.update!(vehicles: [], player_poptabs: 25)

              # The retry names no package. A waiting claim is the thing being delivered, and the player has nothing to
              # name it with - the website's Deliver button knows only that a claim exists.
              execute!(arguments: {server_id: server.server_id})
              ESM.discord_bot.test_outbox.await_size(2)

              accept_request

              expect(ESM::ServerRewardClaim.find_by(user_id: user.id, server_id: server.id)).to be_nil

              expect(ESM::Cooldown.where(command_name: "reward").pluck(:scope_key)).to eq(["daily"])
            end
          end

          context "when different buckets fail for different reasons" do
            # The invalid item adds the extra "Invalid Reward Item" admin log
            let!(:number_of_messages) { 5 }

            let(:reward_vehicles) do
              [{class_name: vehicle_class, spawn_location: "player_decides"}]
            end

            before do
              server.server_rewards.default.first.update!(reward_items: {NotAThingAnyoneOwns: 1})
            end

            it "records each failure against its own bucket" do
              execute_command

              failures = claim.state_details[:failures]

              expect(failures.map { |failure| failure[:bucket] }).to contain_exactly("items", "vehicles")

              # The item cannot be retried into existence, so only the vehicle is still owed
              expect(claim.items).to eq({})
              expect(claim.vehicles.first[:class_name]).to eq(vehicle_class)
            end
          end

          # A package can be nothing but items and vehicles, and both of those fail on their own, so "some of it
          # landed" and "none of it landed" are different answers to the player
          context "when nothing at all can be delivered" do
            # The invalid item adds the extra "Invalid Reward Item" admin log
            let!(:number_of_messages) { 5 }

            let(:reward_vehicles) do
              [{class_name: vehicle_class, spawn_location: "player_decides"}]
            end

            before do
              server.server_rewards.default.first.update!(
                reward_items: {NotAThingAnyoneOwns: 1},
                player_poptabs: 0
              )
            end

            it "does not read back an empty receipt" do
              execute_command

              embed = ESM.discord_bot.test_outbox.retrieve("none of this reward")&.content

              expect(embed).not_to be(nil)
              expect(embed.description).not_to match("here's what you just received")
              expect(embed.description).to match("Hatchback")
              expect(embed.color).to eq(ESM::Color::Toast::RED)
            end

            it "keeps the claim and counts the attempt" do
              execute_command

              expect(claim).to be_present
              expect(claim.attempt_count).to eq(1)
              expect(claim.vehicles.first[:class_name]).to eq(vehicle_class)
            end
          end

          context "when a claim runs out of attempts" do
            let(:reward_vehicles) do
              [{class_name: vehicle_class, spawn_location: "player_decides"}]
            end

            # One short of the cap, standing in for a player who has already tried and failed that many times
            let!(:pending_claim) do
              ESM::ServerRewardClaim.create!(
                server_id: server.id,
                user_id: user.id,
                player_poptabs: 0,
                locker_poptabs: 0,
                respect: 0,
                items: {},
                vehicles: reward_vehicles,
                state: :waiting,
                attempt_count: ESM::Command::Server::Reward::MAX_DELIVERY_ATTEMPTS - 1
              )
            end

            it "stops accepting attempts but keeps what is owed" do
              execute_command

              claim = pending_claim.reload

              expect(claim).to be_failed
              expect(claim.attempt_count).to eq(ESM::Command::Server::Reward::MAX_DELIVERY_ATTEMPTS)
              expect(claim.vehicles.first[:class_name]).to eq(vehicle_class)
            end

            it "sends them somewhere that can finish it" do
              execute_command

              expect {
                execute!(arguments: {server_id: server.server_id})
              }.to raise_error(ESM::Exception::CheckFailure) do |error|
                expect(error.to_embed.description).to match("hasn't gone through after 5 attempts")
              end
            end
          end

          context "when a vehicle spawns nearby" do
            let(:reward_vehicles) do
              [{class_name: vehicle_class, spawn_location: "nearby"}]
            end

            # Test players spawn at [0, 0, 0] because exile_player's position columns default to zero, and that corner
            # is ocean. A nearby spawn searches 250m for somewhere to put the vehicle, so it needs the player on land.
            before do
              execute_sqf!(
                <<~SQF
                  private _playerObject = objectFromNetId "#{user.net_id}";
                  private _position = [getPosATL _playerObject, 0, 5000, 15, 0, 0.3, 0] call BIS_fnc_findSafePos;

                  _playerObject setPosATL [_position select 0, _position select 1, 0];
                  true
                SQF
              )
            end

            it "delivers it with a pin and settles the claim" do
              execute_command

              # The request tells the player a vehicle is coming and where it will turn up
              request = ESM.discord_bot.test_outbox.retrieve("Before we get to the good stuff")&.content

              expect(request).not_to be(nil)
              expect(request.description).to match(/\*\*Vehicles:\*\* .+ - spawned nearby/)

              embed = ESM.discord_bot.test_outbox.retrieve("here's what you just received")&.content

              expect(embed).not_to be(nil)
              expect(embed.description).to match(/Hatchback \(pin `\d{4}`\)/)

              expect(claim).to be_nil
              expect(reward_cooldown).to be_present
            end
          end
        end
      end
    end

    # The #on_execute block already covers delivery and settlement. This only proves the website-specific wiring: the
    # choices a form can collect reaching the extension, and what the row records for the page to read back.
    describe "#on_website_execute", requires_connection: true, server_version: ">= 2.1" do
      include_context "connection"

      let(:vehicle_class) { "Exile_Car_Hatchback_Rusty1" }
      let(:reward_vehicles) { [] }
      let(:vehicles) { nil }

      let(:claim) { ESM::ServerRewardClaim.find_by(user_id: user.id, server_id: server.id) }

      subject(:service_command) do
        execute_website!(
          arguments: {server_id: server.server_id, community_id: community.community_id, vehicles:}
        )
      end

      before do
        # Delivery needs the player in game regardless of which surface asked for it
        spawn_player_for(user)

        server.server_rewards.default.first.update!(
          reward_items: {},
          reward_vehicles:,
          player_poptabs: 10,
          locker_poptabs: 0,
          respect: 0,
          cooldown_quantity: 2,
          cooldown_type: "hours"
        )
      end

      # Test players spawn at [0, 0, 0] because exile_player's position columns default to zero, and that corner is
      # ocean. A nearby spawn searches 250m for somewhere to put the vehicle, so it needs the player on land.
      def move_player_to_land!
        execute_sqf!(
          <<~SQF
            private _playerObject = objectFromNetId "#{user.net_id}";
            private _position = [getPosATL _playerObject, 0, 5000, 15, 0, 0.3, 0] call BIS_fnc_findSafePos;

            _playerObject setPosATL [_position select 0, _position select 1, 0];
            true
          SQF
        )
      end

      context "when the package asks nothing of the player" do
        it "delivers it and completes the row" do
          expect(service_command.status).to eq("completed")
          expect(service_command.result[:state]).to eq("success")
          expect(service_command.result[:failures]).to be_empty

          expect(claim).to be_nil
        end
      end

      context "when the player decides where a vehicle goes" do
        let(:reward_vehicles) { [{class_name: vehicle_class, spawn_location: "player_decides"}] }
        let(:vehicles) { [{"spawn_location" => "nearby", "pin_code" => "4821"}] }

        before { move_player_to_land! }

        # Discord cannot ask this question, so the same package left as a partial claim there. Here it just lands.
        it "spawns it where they asked and settles the claim" do
          expect(service_command.status).to eq("completed")
          expect(service_command.result[:state]).to eq("success")

          expect(claim).to be_nil
        end
      end

      context "when the admin already picked the spawn location" do
        let(:reward_vehicles) { [{class_name: vehicle_class, spawn_location: "nearby"}] }

        # Honouring this would send the vehicle to a garage it has no territory for and fail, rather than spawning it
        # next to the player, which is what makes the override observable
        let(:vehicles) { [{"spawn_location" => "virtual_garage"}] }

        before { move_player_to_land! }

        it "ignores the player's attempt to change it" do
          expect(service_command.status).to eq("completed")
          expect(service_command.result[:state]).to eq("success")

          expect(claim).to be_nil
        end
      end

      # The only choice that carries a territory, so the only one proving an encoded ID survives the extension's decode
      # and reaches SQF as the database ID the flag is looked up by
      context "when the player sends a vehicle to a territory's garage" do
        let(:territory_owner) { user.steam_uid }
        let(:reward_vehicles) { [{class_name: vehicle_class, spawn_location: "player_decides"}] }
        let(:vehicles) { [{"spawn_location" => "virtual_garage", "territory_id" => territory.encoded_id}] }

        # Level 2 is the first with a garage in Exile's shipped config. The flag loads its level from the row.
        before do
          territory.update!(level: 2)
          territory.create_flag
        end

        it "stores it in that garage and settles the claim" do
          expect(service_command.status).to eq("completed")
          expect(service_command.result[:state]).to eq("success")
          expect(service_command.result[:failures]).to be_empty

          expect(claim).to be_nil

          stored_vehicles = get_territory_variable!(territory.id, "ExileTerritoryStoredVehicles")
          expect(stored_vehicles.map(&:first)).to eq([vehicle_class])
        end

        # The picker only lists their own territories, so this is a hand-built request naming somebody else's
        context "and the territory is not theirs" do
          let(:territory_owner) { Faker::Steam.uid }

          it "stores nothing and keeps the vehicle on the claim" do
            expect(service_command.status).to eq("completed")
            expect(service_command.result[:state]).not_to eq("success")

            expect(claim).to be_present
            expect(claim.vehicles.first[:class_name]).to eq(vehicle_class)
            expect(claim.state_details[:failures].first[:reason]).to match("could not be found")

            expect(get_territory_variable!(territory.id, "ExileTerritoryStoredVehicles")).to be_empty
          end
        end
      end

      context "when a pin is not four digits" do
        let(:reward_vehicles) { [{class_name: vehicle_class, spawn_location: "player_decides"}] }
        let(:vehicles) { [{"spawn_location" => "nearby", "pin_code" => "12"}] }

        it "fails the row rather than quietly generating one they will never see" do
          expect(service_command.status).to eq("failed")
          expect(service_command.error_message).to match(/four digits/)

          expect(claim).to be_nil
        end
      end

      context "when the choices no longer line up with the claim" do
        let(:reward_vehicles) { [{class_name: vehicle_class, spawn_location: "player_decides"}] }
        let(:vehicles) do
          [{"spawn_location" => "nearby"}, {"spawn_location" => "nearby"}]
        end

        it "fails the row instead of guessing which vehicle each choice belongs to" do
          expect(service_command.status).to eq("failed")
          expect(service_command.error_message).to match(/Refresh/)
        end
      end
    end
  end
end
