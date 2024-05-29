# frozen_string_literal: true

describe ESM::Command::Server::Sqf, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      before do
        grant_command_access!(community, "sqf")
      end

      context "when the target is omitted" do
        context "and when the code has a return value" do
          it "executes the code on the server and returns the result" do
            wsc.flags.WITH_RETURN = true

            request = execute!(
              arguments: {
                server_id: server.server_id,
                execute: "_test = true;\n_test"
              }
            )

            expect(request).not_to be_nil
            wait_for { connection.requests }.to be_blank
            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = ESM::Test.messages.first.content
            expect(embed).to have_attributes(description: a_string_matching(/executed your code successfully and the code returned the following: ```true```/i))
          end
        end

        context "and when the code does not return anything" do
          it "executes the code on the server and returns nothing" do
            request = execute!(
              arguments: {
                server_id: server.server_id,
                code_to_execute: "if (false) then { \"true\" };"
              }
            )

            expect(request).not_to be_nil
            wait_for { connection.requests }.to be_blank
            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = ESM::Test.messages.first.content
            expect(embed).to have_attributes(description: a_string_matching(/executed your code successfully and the code returned nothing/i))
          end
        end
      end

      context "when the target is provided" do
        context "and when the code does not return anything" do
          it "executes the code on the target and returns nothing" do
            request = execute!(
              arguments: {
                server_id: server.server_id,
                target: user.mention,
                code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
              }
            )

            expect(request).not_to be_nil
            wait_for { connection.requests }.to be_blank
            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = ESM::Test.messages.first.content
            expect(embed).to have_attributes(
              description: a_string_matching(/executed your code successfully on `#{user.steam_uid}`/i)
            )
          end
        end

        context "and when the target is offline" do
          it "returns an error" do
            wsc.flags.ERROR = true

            request = execute!(
              arguments: {
                server_id: server.server_id,
                target: user.mention,
                code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
              }
            )

            expect(request).not_to be_nil
            wait_for { connection.requests }.to be_blank
            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = ESM::Test.messages.first.content
            expect(embed).to have_attributes(
              description: a_string_matching(
                /has informed me that `#{user.steam_uid}` is not online or has not joined the server/i
              )
            )
          end
        end

        context "when the target is not registered" do
          it "returns an error" do
            execution_args = {
              arguments: {
                server_id: server.server_id,
                target: second_user.mention,
                code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
              }
            }

            second_user.update(steam_uid: "")

            expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
              expect(error.data).to have_attributes(description: a_string_matching(/has not registered with me yet/i))
            end
          end
        end

        context "when the target is a steam uid" do
          it "executes the code on the associated player" do
            steam_uid = second_user.steam_uid
            second_user.update(steam_uid: "")

            execute!(
              arguments: {
                server_id: server.server_id,
                target: steam_uid,
                code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
              }
            )

            wait_for { connection.requests }.to be_blank
            wait_for { ESM::Test.messages.size }.to eq(1)

            embed = ESM::Test.messages.first.content
            expect(embed).to have_attributes(
              description: a_string_matching(/executed your code successfully on `#{steam_uid}`/i)
            )
          end
        end
      end
    end
  end

  describe "V2", v2: true do
    it "is an admin command" do
      expect(command.type).to eq(:admin)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    # Change "requires_connection" to true if this command requires the client to be connected
    describe "#on_execute", :requires_connection do
      include_context "connection"

      before do
        grant_command_access!(community, "sqf")
        user.exile_account
      end

      context "when the code is executed on the server and the code returns a result" do
        it "executes the code and a success embed is sent containing the result" do
          execute!(
            arguments: {server_id: server.server_id, code_to_execute: "_test = true;\n_test"}
          )

          wait_for { ESM::Test.messages }.not_to be_empty

          message = ESM::Test.messages.first
          expect(message).not_to be_nil

          result_embed = message.content
          expect(result_embed.description).to eq(
            previous_command.t("responses.server_with_result", server_id: server.server_id, result: "true", user: user.mention)
          )
        end
      end

      context "when the code is executed on the server and the code does not return a result" do
        it "executes the code and a success embed is sent without the result" do
          execute!(
            arguments: {
              server_id: server.server_id,
              code_to_execute: "if (false) then { \"true\" };"
            }
          )

          wait_for { ESM::Test.messages }.not_to be_empty

          message = ESM::Test.messages.first
          expect(message).not_to be_nil

          result_embed = message.content
          expect(result_embed.description).to eq(
            previous_command.t("responses.server", server_id: server.server_id, user: user.mention)
          )
        end
      end

      context "when the code is executed on the player" do
        it "executes the code and a success embed is sent without the result" do
          user.connect

          execute!(
            arguments: {
              server_id: server.server_id,
              target: user.mention,
              code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
            }
          )

          wait_for { ESM::Test.messages }.not_to be_empty

          message = ESM::Test.messages.first
          expect(message).not_to be_nil

          result_embed = message.content
          expect(result_embed.description).to eq(
            previous_command.t(
              "responses.player",
              server_id: server.server_id,
              user: user.mention,
              target_uid: user.steam_uid
            )
          )
        end
      end

      context "when the code is executed on a non-registered steam uid" do
        it "executes the code and a success embed is sent without the result" do
          second_user.connect

          # Deregister the user
          steam_uid = second_user.steam_uid
          second_user.update(steam_uid: nil)

          execute!(
            arguments: {
              server_id: server.server_id,
              target: steam_uid,
              code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
            }
          )

          wait_for { ESM::Test.messages }.not_to be_empty

          message = ESM::Test.messages.first
          expect(message).not_to be_nil

          result_embed = message.content
          expect(result_embed.description).to eq(
            previous_command.t(
              "responses.player",
              server_id: server.server_id,
              user: user.mention,
              target_uid: steam_uid
            )
          )
        end
      end

      context "when the registered target player is not spawned on the server" do
        before do
          second_user.exile_account&.delete
        end

        it "raises NullTarget error code with the target's discord mention" do
          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
            }
          )

          wait_for { ESM::Test.messages }.not_to be_empty

          message = ESM::Test.messages.first
          expect(message).not_to be_nil

          result_embed = message.content
          expect(result_embed.description).to eq(
            "Hey #{user.mention}, #{second_user.mention} **needs to join** `#{server.server_id}` before you can execute code on them"
          )
        end
      end

      context "when the target is an unregistered steam uid that is not spawned on the server" do
        before do
          second_user.exile_account&.delete
        end

        it "raises NullTarget error with the steam uid" do
          steam_uid = second_user.steam_uid
          second_user.deregister!

          execute!(
            handle_error: true,
            arguments: {
              server_id: server.server_id,
              target: steam_uid,
              code_to_execute: "player setVariable [\"This code\", \"does not matter\"];"
            }
          )

          wait_for { ESM::Test.messages }.not_to be_empty

          message = ESM::Test.messages.first
          expect(message).not_to be_nil

          result_embed = message.content
          expect(result_embed.description).to eq(
            "Hey #{user.mention}, #{steam_uid} **needs to join** `#{server.server_id}` before you can execute code on them"
          )
        end
      end
    end
  end
end
