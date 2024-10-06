# frozen_string_literal: true

describe ESM::Command::Server::Gamble, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when the amount is a number" do
        it "gambles with the amount of poptabs on the server" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "300"})

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the amount is 'half'" do
        it "gambles half of the user's poptabs on the server" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "half"})

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the amount is 'all'" do
        it "gambles all of the players money" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "all"})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the user does not have enough poptabs" do
        it "returns an error from the server" do
          wsc.flags.NOT_ENOUGH_MONEY = true

          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "100000000"})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to match(/not enough poptabs/i)
        end
      end

      context "when the amount is 0" do
        it "raises an exception" do
          execution_args = {channel_type: :dm, arguments: {server_id: server.server_id, amount: "0"}}

          expect { execute!(**execution_args) }.to raise_error(
            ESM::Exception::CheckFailure,
            /you simply cannot gamble nothing/
          )
        end
      end

      context "when the amount is negative" do
        it "raises an exception" do
          execution_args = {channel_type: :dm, arguments: {server_id: server.server_id, amount: "-1"}}

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
        end
      end

      context "when the amount is 'stats'" do
        it "returns the gambling stats for the server" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "stats"})

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).to match("Gambling statistics")
          expect(embed.fields.size).to eq(14)
        end
      end

      context "when the amount is omitted" do
        it "returns the gambling stats for the server" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id})

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).to match("Gambling statistics")
          expect(embed.fields.size).to eq(14)
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

      let(:locker_balance) { 5_000 }  # yea
      let(:amount) {}

      let(:server_setting_default) do
        {gambling_locker_limit_enabled: false}
      end

      let(:server_setting) { {} }

      subject(:execute_command) do
        execute!(arguments: {server_id: server.server_id, amount:})
      end

      ##########################################################################
      # Callbacks

      before do
        server.server_setting.update!(server_setting_default.merge(server_setting))
        user.exile_account.update!(locker: locker_balance)
      end

      ##########################################################################
      # Examples

      shared_examples "reply_with_stats" do
        it "is expected to reply back with the stats" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.retrieve(
            "Gambling statistics for `#{server.server_id}`"
          )&.content

          expect(embed).not_to be(nil)

          expect(embed.fields.size).to eq(14)
        end
      end

      shared_examples "raise_bad_amount" do
        include_examples "raises_check_failure" do
          let(:matcher) { "I'm sorry #{user.mention}, but you simply cannot gamble nothing." }
        end
      end

      shared_examples "successful_gamble_won" do |it_message = nil|
        let!(:server_setting) do
          {
            gambling_win_percentage: 100,
            gambling_payout_base: 100,
            gambling_modifier: 1,
            gambling_payout_randomizer_min: 1,
            gambling_payout_randomizer_mid: 1,
            gambling_payout_randomizer_max: 1
          }
        end

        let(:streak) { 1 }
        let(:won_amount) { amount * 3 } # With everything set to 1
        let(:won_amount_delimited) { won_amount.to_delimitated_s }

        it(it_message || "is expected to gamble the amount and won") do
          execute_command

          wait_for { ESM::Test.messages.size }.to be > 1

          embed = ESM::Test.messages.retrieve("Winner winner!")&.content

          expect(embed).not_to be(nil)
          expect(embed.description).to match("#{won_amount_delimited} poptabs")
          expect(embed.footer.text).to eq("Current Streak: #{streak}")

          new_locker_balance = locker_balance + won_amount
          if defined?(net_id)
            locker = execute_sqf! <<~SQF
              private _playerObject = objectFromNetID "#{net_id}";
              if (isNull _playerObject) exitWith { nil };

              _playerObject getVariable ["ExileLocker", -1]
            SQF

            expect(locker).to eq(new_locker_balance)
          end

          user.exile_account.reload
          expect(user.exile_account.reload.locker).to eq(new_locker_balance)
        end
      end

      shared_examples "successful_gamble_loss" do |it_message = nil|
        let!(:server_setting) { {gambling_win_percentage: 0} }

        let(:streak) { 1 }
        let(:loss_amount) { amount }
        let(:loss_amount_delimited) { loss_amount.to_delimitated_s }

        it(it_message || "is expected to gamble the amount and lost") do
          execute_command

          wait_for { ESM::Test.messages.size }.to be > 1

          embed = ESM::Test.messages.retrieve("Better luck next time!")&.content

          expect(embed).not_to be(nil)
          expect(embed.description).to match("#{loss_amount_delimited} poptabs")
          expect(embed.footer.text).to eq("Current Streak: #{streak}")

          new_locker_balance = locker_balance - loss_amount
          if defined?(net_id)
            locker = execute_sqf! <<~SQF
              private _playerObject = objectFromNetID "#{net_id}";
              if (isNull _playerObject) exitWith { nil };

              _playerObject getVariable ["ExileLocker", -1]
            SQF

            expect(locker).to eq(new_locker_balance)
          end

          user.exile_account.reload
          expect(user.exile_account.reload.locker).to eq(new_locker_balance)
        end
      end

      ##########################################################################
      # Tests

      context "when the amount is omitted", requires_connection: false do
        let!(:amount) { nil }

        include_examples "reply_with_stats"
      end

      ###

      context "when the amount is 'stats'", requires_connection: false do
        let!(:amount) { "stats" }

        include_examples "reply_with_stats"
      end

      ###

      context "when the server is not connected", requires_connection: false do
        context "and the stats are requested" do
          let!(:amount) { "stats" }

          include_examples "reply_with_stats"
        end

        context "and an amount is given" do
          let!(:amount) { 100 }

          include_examples "raises_server_not_connected"
        end
      end

      ###

      context "when the amount is negative" do
        let(:amount) { -1 }

        include_examples "raise_bad_amount"
      end

      ###

      context "when the amount is zero" do
        let!(:amount) { 0 }

        include_examples "raise_bad_amount"
      end

      ###

      context "when the amount is a positive number" do
        let!(:amount) { 50 }

        context "and the player is online and they won" do
          let!(:net_id) { spawn_player_for(user) }

          include_examples "successful_gamble_won"
        end

        ##

        context "and the player is online and they lost" do
          let!(:net_id) { spawn_player_for(user) }

          include_examples "successful_gamble_loss"
        end

        ##

        context "and the player is offline and they won" do
          include_examples "successful_gamble_won"
        end

        ##

        context "and the player is offline and they lost" do
          include_examples "successful_gamble_loss"
        end

        ##

        context "and the player has a winning streak" do
          include_examples "successful_gamble_won" do
            let(:streak) { 2 }

            before do
              user.user_gamble_stats.first_or_initialize.update!(
                server:,
                current_streak: 1,
                last_action: described_class::WON_ACTION
              )
            end
          end
        end

        ##

        context "and the player has a losing streak" do
          include_examples "successful_gamble_loss" do
            let(:streak) { 2 }

            before do
              user.user_gamble_stats.first_or_initialize.update!(
                server:,
                current_streak: 1,
                last_action: described_class::LOSS_ACTION
              )
            end
          end
        end
      end

      ###

      context "when the amount is 'all'" do
        let!(:amount) { "all" }

        include_examples(
          "successful_gamble_loss",
          "is expected to gamble all of the poptabs and lose"
        ) do
          let!(:loss_amount) { locker_balance }
        end

        context "and the player has no money" do
          # We don't store locker data so the extension has to handle this check
          let!(:locker_balance) { 0 }

          include_examples(
            "raises_extension_error",
            "is expected to raise Gamble_CannotGambleNothing"
          ) do
            let!(:matcher) { "#{user.mention}, you cannot gamble nothing!" }
          end
        end
      end

      ###

      context "when the amount is 'half'" do
        let!(:amount) { "half" }

        include_examples(
          "successful_gamble_loss",
          "is expected to gamble half of the poptabs and lose"
        ) do
          let!(:loss_amount) { locker_balance / 2 }
        end

        context "and the player has no money" do
          # We don't store locker data so the extension has to handle this check
          let!(:locker_balance) { 0 }

          include_examples(
            "raises_extension_error",
            "is expected to raise Gamble_CannotGambleNothing"
          ) do
            let!(:matcher) { "#{user.mention}, you cannot gamble nothing!" }
          end
        end
      end

      ###

      context "when logging is enabled" do
        let!(:amount) { 1 }

        # Loss
        let!(:server_setting) { {gambling_win_percentage: 0, logging_gamble: true} }

        include_examples "arma_discord_logging_enabled" do
          let(:message) { "`ESMs_command_gamble` executed successfully" }

          let(:fields) do
            [
              player_field,
              {
                name: "Locker before",
                value: locker_balance.to_delimitated_s,
                inline: true
              },
              {
                name: "Locker after",
                value: (locker_balance - amount).to_delimitated_s,
                inline: true
              }
            ]
          end
        end
      end

      ###

      context "when logging is disabled" do
        let!(:amount) { 1 }

        # Loss
        let!(:server_setting) { {gambling_win_percentage: 0, logging_gamble: false} }

        include_examples "arma_discord_logging_disabled" do
          let(:message) { "`ESMs_command_gamble` executed successfully" }
        end
      end

      ###

      context "when the player is gambling more than what they have" do
        let!(:amount) { 1_000 }
        let!(:locker_balance) { 0 }

        include_examples "arma_error_too_poor"
      end

      ###

      context "when the locker limit is enabled" do
        let!(:amount) { 1_000 }

        # Win
        let!(:server_setting) do
          {gambling_locker_limit_enabled: true, gambling_win_percentage: 100}
        end

        let!(:max_deposit) do
          execute_sqf!("getNumber(missionConfigFile >> 'CfgLocker' >> 'maxDeposit')")
        end

        context "and the player has too many poptabs in their locker before gambling" do
          let!(:locker_balance) { max_deposit }

          include_examples "raises_extension_error", "is expected to raise Gamble_LockerFull" do
            let!(:matcher) { "#{user.mention}, your locker is full" }
          end
        end

        ##

        context "and the player has too many poptabs in their locker after gambling" do
          let!(:locker_balance) { max_deposit - amount }

          it "is expected to succeed but caps the locker amount to maxDeposit" do
            execute_command

            wait_for { ESM::Test.messages.size }.to be > 1

            embed = ESM::Test.messages.retrieve("Winner winner!")&.content

            expect(embed).not_to be(nil)
            expect(embed.description).to match("poptabs due to server limits")
            expect(user.exile_account.reload.locker).to eq(max_deposit)
          end
        end
      end
    end
  end
end
