# frozen_string_literal: true

describe ESM::Command::Territory::Upgrade, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

      context "when the territory can be upgraded" do
        it "is upgraded to the next level" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id, territory_id: territory_id})
          wait_for { connection.requests }.to be_blank
          ESM.discord_bot.test_outbox.await_size(1)

          embed = ESM.discord_bot.test_outbox.first.content
          expect(embed.description).to eq("Hey #{user.mention}, you successfully upgraded territory `#{territory_id}` for **#{response.cost.to_poptab}**.\nYour territory has reached level **#{response.level}** and now has a radius of **#{response.range}** meters.\nAfter this transaction, you have **#{response.locker.to_poptab}** left in your locker.")
        end
      end
    end
  end

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection" do
        let!(:territory_moderators) { [user.steam_uid] }
      end

      let(:territory_purchase_price) do
        server.territories
          .where(territory_level: territory.level)
          .pick(:territory_purchase_price)
      end

      let!(:locker_balance) { 1_000_000 }  # Aww yea

      subject(:execute_command) do
        execute!(arguments: {territory_id: territory.encoded_id, server_id: server.server_id})
      end

      before do
        user.exile_account.update!(locker: locker_balance)
        territory.create_flag
      end

      # Happy path
      shared_examples "successful_territory_upgrade" do
        it "upgrades the territory using poptabs from the player's locker" do
          # territory_purchase_price is keyed on the territory's current level, so it has to be read before the
          # command moves the territory off that level
          previous_level = territory.level
          upgraded_level = previous_level + 1

          # The territories row keyed to the current level is the one being bought: it carries both the price (see
          # the territory_purchase_price let) and the radius the territory ends up with
          expected_radius = server.territories.where(territory_level: previous_level).pick(:territory_radius)

          # Handle taxes
          tax = respond_to?(:territory_upgrade_tax) ? territory_upgrade_tax : 0
          tax = (territory_purchase_price * (tax / 100.0)).to_i if tax > 0
          expected_locker = locker_balance - territory_purchase_price - tax

          execute_command

          ESM.discord_bot.test_outbox.await_size(2)

          # Player response
          expect(
            ESM.discord_bot.test_outbox.retrieve(
              "`#{territory.encoded_id}` has been upgraded to level #{upgraded_level}"
            )
          ).not_to be(nil)

          # Admin log
          expect(
            ESM.discord_bot.test_outbox.retrieve("Territory upgraded to level #{upgraded_level}")
          ).not_to be(nil)

          expect_locker_to_eq(
            user, expected_locker,
            "Purchase price: #{territory_purchase_price}. Tax: #{tax}"
          )

          territory.reload

          expect(territory.level).to eq(upgraded_level)
          expect(territory.radius).to eq(expected_radius)

          # moderators and build rights ride along to catch the upgrade reaching further than the level and size
          expect_territory_flag_to_match_database(:level, :radius, :moderators, :build_rights)
        end
      end

      context "when the player is online, is a moderator, and upgrades the territory" do
        before { spawn_player_for(user) }

        include_examples "successful_territory_upgrade"
      end

      context "when the player is offline, is a moderator, and upgrades the territory" do
        include_examples "successful_territory_upgrade"
      end

      context "when the player is a territory admin" do
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          territory.revoke_membership(user.steam_uid)
          expect(territory.moderators).not_to include(user.steam_uid)
        end

        include_examples "successful_territory_upgrade"
      end

      context "when there is tax on the upgrade" do
        let(:territory_upgrade_tax) { Faker::Number.between(from: 1, to: 100) }

        before do
          server.server_setting.update!(territory_upgrade_tax:)
        end

        include_examples "successful_territory_upgrade" do
          it { expect(territory_upgrade_tax).not_to eq(0) }
        end
      end

      context "when logging is enabled" do
        before do
          server.server_setting.update!(logging_upgrade_territory: true)
        end

        include_examples "arma_discord_logging_enabled" do
          let(:message) { "`ESMs_command_upgrade` executed successfully" }

          before do
            # This log does not contain the target entry
            fields.delete_at(2)
          end
        end
      end

      context "when logging is disabled" do
        before do
          server.server_setting.update!(logging_upgrade_territory: false)
        end

        include_examples "arma_discord_logging_disabled" do
          let(:message) { "`ESMs_command_upgrade` executed successfully" }
        end
      end

      context "when the player has not joined the server" do
        before { user.exile_account.destroy! }

        include_examples "arma_error_player_needs_to_join"
      end

      context "when the territory is null" do
        before { territory.delete_flag }

        include_examples "arma_error_null_flag"
      end

      context "when the player does not have permissions to upgrade" do
        before do
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "arma_error_missing_territory_access"
      end

      context "when the flag has been stolen" do
        before do
          territory.update!(flag_stolen: true)
        end

        include_examples "arma_error_flag_stolen"
      end

      context "when the flag is already at max level" do
        before do
          territory.update!(level: server.territories.size)
        end

        it "raise Upgrade_MaxLevel" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.to_embed.description).to match("already at the highest level")
          end
        end
      end

      context "when the player is online and does not have enough poptabs" do
        let(:locker_balance) { 0 }

        before { spawn_player_for(user) }

        include_examples "arma_error_too_poor_with_cost"
      end

      context "when the player is not online and does not have enough poptabs" do
        let(:locker_balance) { 0 }

        include_examples "arma_error_too_poor_with_cost"
      end
    end
  end
end
