# frozen_string_literal: true

describe ESM::Command::Server::Sqf, category: "command", v2: true do
  include_context "command"
  include_examples "validate_command"

  it "is an admin command" do
    expect(command.type).to eql(:admin)
  end

  it "requires registration" do
    expect(command.registration_required?).to be(true)
  end

  # Change "requires_connection" to true if this command requires the client to be connected
  describe "#on_execute/#on_response", requires_connection: true do
    include_context "connection"

    let(:second_user) { ESM::Test.user }

    before :each do
      grant_command_access!(community, "sqf")
    end

    it "executes (On server/with result)" do
      execute!(server_id: server.server_id, code_to_execute: "_test = true;\n_test")
      wait_for { ESM::Test.messages }.not_to be_empty

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq(command.t("responses.server_with_result", server_id: server.server_id, result: "true", user: user.mention))
    end

    it "executes (On server/no result)" do
      execute!(server_id: server.server_id, code_to_execute: "if (false) then { \"true\" };")
      wait_for { ESM::Test.messages }.not_to be_empty

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq(command.t("responses.server", server_id: server.server_id, user: user.mention))
    end

    it "executes (On player/no result)" do
      user.connect

      execute!(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      wait_for { ESM::Test.messages }.not_to be_empty

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq(command.t("responses.player", server_id: server.server_id, user: user.mention, target_uid: user.steam_uid))
    end

    it "executes (On non-registered steam uid)" do
      second_user.connect

      # Deregister the user
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: nil)

      execute!(fail_on_raise: false, server_id: server.server_id, target: steam_uid, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      wait_for { ESM::Test.messages }.not_to be_empty

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq(command.t("responses.player", server_id: server.server_id, user: user.mention, target_uid: steam_uid))
    end

    it "returns a client error (Player is not online)" do
      execute!(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
      wait_for { ESM::Test.messages }.not_to be_empty

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq("Hey #{user.mention}, `#{user.steam_uid}` must be spawned into `#{server.server_id}` before you can execute code on them")
    end

    it "raises (Player is not registered)" do
      second_user.update(steam_uid: nil)

      begin
        execute!(fail_on_raise: false, server_id: server.server_id, target: second_user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")

        raise "Unreachable"
      rescue ESM::Exception::CheckFailure => e
        expect(e.data.description).to eq("Hey #{user.mention}, #{second_user.mention} has not registered with me yet. Tell them to head over to https://www.esmbot.com/register to get started!")
      end
    end

    it "minifies the code" do
      execute!(
        server_id: server.server_id,
        target: "server",
        code_to_execute: <<~SQF
          if (true) exitWith
          {
            false
          };
        SQF
      )

      wait_for { ESM::Test.messages }.not_to be_empty

      outgoing_message = ESM::Test.outbound_server_messages.first.content
      expect(outgoing_message.data.code).to eq("if(true)exitWith{false};")

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq(command.t("responses.server_with_result", server_id: server.server_id, result: "false", result_type: "BOOL", user: user.mention))
    end
  end
end
