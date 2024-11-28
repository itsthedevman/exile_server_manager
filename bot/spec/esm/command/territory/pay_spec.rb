# frozen_string_literal: true

describe ESM::Command::Territory::Pay, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when the execution is valid" do
        it "returns a success message" do
          request = execute!(
            channel_type: :dm,
            arguments: {server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5]}
          )

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to match(/has successfully received the payment/i)
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
        let!(:territory_build_rights) { [user.steam_uid] }
      end

      let(:locker_balance) { 1_000_000 }  # Aww yea

      let!(:territory_price_per_object) do
        execute_sqf!(
          <<~STRING
            getNumber (missionConfigFile >> "CfgTerritories" >> "popTabAmountPerObject")
          STRING
        )
      end

      let(:territory_protection_price) do
        territory.level * territory_price_per_object * territory.number_of_constructions
      end

      subject(:execute_command) do
        execute!(arguments: {territory_id: territory.encoded_id, server_id: server.server_id})
      end

      before do
        user.exile_account.update!(locker: locker_balance)
        territory.number_of_constructions = 15
        territory.create_flag
      end

      # Happy path
      shared_examples "successful_territory_payment" do
        it "pays the territory's protection money using poptabs from the player's locker" do
          execute_command

          # Player response, admin log, xm8 notification
          wait_for { ESM::Test.messages.size }.to be >= 2

          # Player response
          expect(
            ESM::Test.messages.retrieve(
              "Successfully paid protection money for territory `#{territory.encoded_id}`"
            )
          ).not_to be(nil)

          # Admin log
          expect(
            ESM::Test.messages.retrieve("Territory protection money paid")
          ).not_to be(nil)

          user.exile_account.reload

          # Handle taxes
          tax = respond_to?(:territory_payment_tax) ? territory_payment_tax : 0
          tax = (territory_protection_price * (tax / 100.0)).to_i if tax > 0

          expect(user.exile_account.locker).to eq(locker_balance - territory_protection_price - tax)

          territory.reload

          # Check for increased payment counter
          expect(territory.esm_payment_counter).to eq(1)

          # Check for time change
          expect(territory.last_paid_at).not_to be(nil)
        end
      end

      context "when the territory protection money is paid" do
        it "sends an XM8 notification" do
          execute_command

          notifications = ESM::ExileXm8Notification.protection_money_paid.sent
          wait_for { notifications.size }.to eq(1)
        end
      end

      context "when the player is online, is a builder, and upgrades the territory" do
        before { spawn_player_for(user) }

        include_examples "successful_territory_payment"
      end

      context "when the player is offline, is a builder, and upgrades the territory" do
        include_examples "successful_territory_payment"
      end

      context "when the player is a territory admin" do
        let!(:territory_admin_uids) { [user.steam_uid] }

        before do
          territory.revoke_membership(user.steam_uid)
          expect(territory.build_rights).not_to include(user.steam_uid)
        end

        include_examples "successful_territory_payment"
      end

      context "when there is tax on the payment" do
        let(:territory_payment_tax) { Faker::Number.between(from: 1, to: 100) }

        before do
          server.server_setting.update!(territory_payment_tax:)
        end

        include_examples "successful_territory_payment" do
          it { expect(territory_payment_tax).not_to eq(0) }
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

      context "when the player is not a member of this territory" do
        before { territory.revoke_membership(user.steam_uid) }

        include_examples "arma_error_missing_territory_access"
      end

      context "when the flag has been stolen" do
        before { territory.update!(flag_stolen: true) }

        include_examples "arma_error_flag_stolen"
      end

      context "when the player is online and does not have enough poptabs" do
        let!(:locker_balance) { 0 }

        before { spawn_player_for(user) }

        include_examples "arma_error_too_poor_with_cost"
      end

      context "when the player is not online and does not have enough poptabs" do
        let!(:locker_balance) { 0 }

        include_examples "arma_error_too_poor_with_cost"
      end
    end
  end
end
