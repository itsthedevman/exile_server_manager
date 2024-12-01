# frozen_string_literal: true

describe ESM::Command::Server::Player, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is an admin command" do
    expect(command.type).to eq(:admin)
  end

  before do
    grant_command_access!(community, "player")
  end

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      describe "Money" do
        let!(:action) { "money" }

        def check!
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)
          embed = ESM::Test.messages.first.second

          expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s money by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
        end

        context "when the action is 'Change player poptabs'" do
          it "modifies the player's money" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action,
                amount: Faker::Number.between(from: -500, to: 500)
              }
            )

            check!
          end

          it "requires an amount" do
            execution_args = {
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action
              }
            }

            expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
          end
        end
      end

      describe "Locker" do
        let!(:action) { "locker" }

        def check!
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)
          embed = ESM::Test.messages.first.second

          expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s locker by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
        end

        context "when the action is 'Change locker poptabs'" do
          it "modifies the player's locker" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action,
                amount: Faker::Number.between(from: -500, to: 500)
              }
            )

            check!
          end

          it "requires an amount" do
            execution_args = {
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action
              }
            }

            expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
          end
        end
      end

      describe "Respect" do
        let!(:action) { "respect" }

        def check!
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)
          embed = ESM::Test.messages.first.second

          expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s respect by #{response.modified_amount.to_readable} points. They used to have #{response.previous_amount.to_readable}, they now have #{response.new_amount.to_readable}.")
        end

        context "when the action is 'Change player respect'" do
          it "modifies the player's respect" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action,
                amount: Faker::Number.between(from: -500, to: 500)
              }
            )

            check!
          end

          it "requires an amount" do
            execution_args = {
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action
              }
            }

            expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
          end
        end
      end

      describe "Heal" do
        let!(:action) { "heal" }

        def check!
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)
          embed = ESM::Test.messages.first.second

          expect(embed.description).not_to be_blank
        end

        context "when the action is 'Heal player'" do
          it "heals the player" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action
              }
            )

            check!
          end

          it "will ignore the amount argument" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action,
                amount: 55
              }
            )

            expect(previous_command.arguments.amount).to be_nil
          end
        end
      end

      describe "Kill" do
        let!(:action) { "kill" }

        def check!
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)
          embed = ESM::Test.messages.first.second

          expect(embed.description).not_to be_blank
        end

        context "when the action is 'Kill player'" do
          it "kills the player" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action
              }
            )

            check!
          end

          it "will ignore the amount argument" do
            execute!(
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                action: action,
                amount: 55
              }
            )

            expect(previous_command.arguments.amount).to be_nil
          end
        end
      end

      context "when the target is a non-registered steam uid" do
        it "works as expected" do
          steam_uid = second_user.steam_uid
          second_user.update(steam_uid: "")

          execute!(
            arguments: {server_id: server.server_id, target: steam_uid, action: "heal"}
          )

          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)
          embed = ESM::Test.messages.first.second

          expect(embed.description).not_to be_blank
        end
      end
    end
  end

  describe "V2", v2: true do
    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let(:action) {}
      let(:amount) {}
      let(:target) { second_user.mention }

      let(:previous_amount) {}
      let!(:final_amount) { previous_amount + amount }

      let!(:account) { second_user.exile_account }
      let!(:player) { second_user.exile_player }

      subject(:execute_command) do
        execute!(
          arguments: {
            server_id: server.server_id,
            target:,
            action:,
            amount:
          }
        )
      end

      before do
        user.exile_account
      end

      context "when the action is 'Change player poptabs'" do
        let!(:action) { "money" }

        shared_examples "modifies" do
          it "modifies the player's poptabs" do
            execute_command

            wait_for { ESM::Test.messages.size }.to eq(2)

            # Admin log
            expect(
              ESM::Test.messages.retrieve("money has been modified")
            ).not_to be(nil)

            # Player response
            embed = ESM::Test.messages.retrieve("money by")&.content
            expect(embed).not_to be(nil)

            expect(embed.description).to eq(
              "#{user.mention}, you've modified `#{second_user.steam_uid}`'s money by #{amount.to_readable} poptabs. They used to have #{previous_amount.to_readable} poptabs, they now have #{final_amount.to_readable}."
            )
          end
        end

        context "and the amount is positive" do
          let!(:previous_amount) { player.money }
          let!(:amount) { Faker::Number.positive.to_i }
          let!(:final_amount) { amount }

          include_examples "modifies"
        end

        context "and the amount is negative" do
          let!(:previous_amount) { 10_000 }
          let!(:amount) { Faker::Number.negative.to_i }

          before do
            player.update!(money: previous_amount)
          end

          include_examples "modifies"
        end

        context "and the amount is not provided" do
          let!(:amount) { nil }
          let!(:final_amount) { nil }

          include_examples "raises_check_failure" do
            let!(:matcher) { "Missing argument" }
          end
        end
      end

      context "when the action is 'Change locker poptabs'" do
        let!(:action) { "locker" }

        shared_examples "modifies" do
          it "modifies the player's locker" do
            execute_command

            wait_for { ESM::Test.messages.size }.to eq(2)

            # Admin log
            expect(
              ESM::Test.messages.retrieve("locker has been modified")
            ).not_to be(nil)

            # Player response
            embed = ESM::Test.messages.retrieve("locker by")&.content
            expect(embed).not_to be(nil)

            expect(embed.description).to eq(
              "#{user.mention}, you've modified `#{second_user.steam_uid}`'s locker by #{amount.to_readable} poptabs. They used to have #{previous_amount.to_readable} poptabs, they now have #{final_amount.to_readable}."
            )
          end
        end

        context "and the amount is positive" do
          let!(:previous_amount) { account.locker }
          let!(:amount) { Faker::Number.positive.to_i }
          let!(:final_amount) { amount }

          include_examples "modifies"
        end

        context "and the amount is negative" do
          let!(:previous_amount) { 10_000 }
          let!(:amount) { Faker::Number.negative.to_i }

          before do
            account.update!(locker: previous_amount)
          end

          include_examples "modifies"
        end

        context "and the amount is not provided" do
          let!(:amount) { nil }
          let!(:final_amount) { nil }

          include_examples "raises_check_failure" do
            let!(:matcher) { "Missing argument" }
          end
        end
      end

      context "when the action is 'Change player respect'" do
        let!(:action) { "respect" }

        shared_examples "modifies" do
          it "modifies the player's respect" do
            execute_command

            wait_for { ESM::Test.messages.size }.to eq(2)

            # Admin log
            expect(
              ESM::Test.messages.retrieve("respect has been modified")
            ).not_to be(nil)

            # Player response
            embed = ESM::Test.messages.retrieve("respect by")&.content
            expect(embed).not_to be(nil)

            expect(embed.description).to eq(
              "#{user.mention}, you've modified `#{second_user.steam_uid}`'s respect by #{amount.to_readable} points. They used to have #{previous_amount.to_readable}, they now have #{final_amount.to_readable}."
            )
          end
        end

        context "and the amount is positive" do
          let!(:previous_amount) { account.score }
          let!(:amount) { Faker::Number.positive.to_i }
          let!(:final_amount) { amount }

          include_examples "modifies"
        end

        context "and the amount is negative" do
          let!(:previous_amount) { 10_000 }
          let!(:amount) { Faker::Number.negative.to_i }

          before do
            account.update!(score: previous_amount)
          end

          include_examples "modifies"
        end

        context "and the amount is not provided" do
          let!(:amount) { nil }
          let!(:final_amount) { nil }

          include_examples "raises_check_failure" do
            let!(:matcher) { "Missing argument" }
          end
        end
      end

      context "when the action is 'Heal player'" do
        let!(:action) { "heal" }

        let!(:amount) { 100 } # This is ignored.
        let!(:final_amount) {}

        it "heals the player" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)

          # Admin log
          expect(
            ESM::Test.messages.retrieve("Target has been healed")
          ).not_to be(nil)

          # Player response
          # Since this is randomized, it's hard to match to
          embed = ESM::Test.messages
            .reject { |m| m.content.to_s.match?("target has been healed") }
            .first
            &.content

          expect(embed).not_to be(nil)
          expect(embed.description).not_to be_blank
        end

        it "ignores the amount argument" do
          execute_command

          expect(previous_command.arguments.amount).to be(nil)
        end
      end

      context "when the action is 'Kill player'" do
        let!(:action) { "kill" }

        let!(:amount) { 100 } # This is ignored.
        let!(:final_amount) {}

        it "kills the player" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)

          # Admin log
          expect(
            ESM::Test.messages.retrieve("Target has been killed")
          ).not_to be(nil)

          # Player response
          # Since this is randomized, it's hard to match to
          embed = ESM::Test.messages
            .reject { |m| m.content.to_s.match?("target has been killed") }
            .first
            &.content

          expect(embed).not_to be(nil)
          expect(embed.description).not_to be_blank
        end

        it "ignores the amount argument" do
          execute_command

          expect(previous_command.arguments.amount).to be(nil)
        end

        context "and the target is already dead" do
          before do
            player.destroy!
          end

          include_examples "raises_extension_error" do
            let!(:matcher) { "is already dead" }
          end
        end
      end

      context "when the target is a non-registered steam uid" do
        let!(:action) { "respect" }
        let!(:amount) { 100 }
        let!(:final_amount) {}
        let!(:target) { second_user.steam_uid }

        it "accepts the steam uid" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)

          # Admin log
          expect(
            ESM::Test.messages.retrieve("respect has been modified")
          ).not_to be(nil)

          # Player response
          embed = ESM::Test.messages.retrieve("respect by")&.content
          expect(embed).not_to be(nil)
        end
      end

      context "when the player has not joined the server" do
        let!(:action) { "kill" }
        let!(:final_amount) {}

        before do
          user.exile_account.destroy!
        end

        include_examples "arma_error_player_needs_to_join"
      end

      context "when the target has not joined the server" do
        let!(:action) { "kill" }
        let!(:final_amount) {}

        before do
          second_user.exile_account.destroy!
        end

        include_examples "arma_error_target_needs_to_join"
      end

      context "when logging is enabled" do
        let!(:action) { "kill" }
        let!(:final_amount) {}

        before do
          server.server_setting.update!(logging_modify_player: true)
        end

        include_examples "arma_discord_logging_enabled" do
          let(:message) { "`ESMs_command_player` executed successfully" }
          let(:fields) { [player_field, target_field] }
        end
      end

      context "when logging is disabled" do
        let!(:action) { "kill" }
        let!(:final_amount) {}

        before do
          server.server_setting.update!(logging_modify_player: false)
        end

        include_examples "arma_discord_logging_disabled" do
          let(:message) { "`ESMs_command_player` executed successfully" }
          let(:fields) { [player_field, target_field] }
        end
      end
    end
  end
end
