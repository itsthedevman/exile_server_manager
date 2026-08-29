# frozen_string_literal: true

describe ESM::Command::Server::Broadcast, category: "command" do
  include_context "command"
  include_examples "validate_command"
  include_examples "preserves_argument_case", message: "Servers are Restarting in 15 Minutes for the Summer Wipe"

  describe "#execute" do
    include_context "connection_v1"

    let!(:second_server) { create(:server, community_id: community.id) }
    let!(:second_wsc) { WebsocketClient.new(second_server) }
    let(:response) { previous_command.response }

    before do
      # Create cooldowns for the users. This is how broadcast knows who to send messages to.
      create(:cooldown, command_name: "preferences", user: user, community: community, server: server)
      create(:cooldown, command_name: "preferences", user: user, community: community, server: second_server)
      create(:cooldown, command_name: "preferences", user: second_user, community: community, server: second_server)

      grant_command_access!(community, "broadcast")

      wait_for { second_wsc.connected? }.to be(true)
    end

    after do
      second_wsc.disconnect!
    end

    context "when a valid server ID is the target" do
      it "sends a message to the users" do
        execute!(arguments: {broadcast_to: server.server_id, message: "Hello world!"}, prompt_response: "yes")

        # 1: Preview Message
        # 2: Spacer
        # 3: Confirmation
        # 4: Success message
        # 5: Message to first user
        ESM.discord_bot.test_outbox.await_size(5)
      end
    end

    context "when 'all' is the target" do
      it "sends a message to every server" do
        execute!(arguments: {broadcast_to: "all", message: "Hello world!"}, prompt_response: "yes")

        # 1: Preview Message
        # 2: Spacer
        # 3: Confirmation
        # 4: Success message
        # 5: Message to first user
        # 6: Message to second user
        ESM.discord_bot.test_outbox.await_size(6)
      end
    end

    context "when the target is omitted" do
      it "sends a preview of the message" do
        execute!(arguments: {message: "Hello world!"})

        # 1: Preview Message
        ESM.discord_bot.test_outbox.await_size(1)
      end
    end

    context "when the user aborts during confirmation" do
      it "does not send any messages" do
        execute!(
          arguments: {broadcast_to: "all", message: "Hello world!"},
          prompt_response: "no"
        )

        # 1: Preview Message
        # 2: Spacer
        # 3: Confirmation
        # 4: Cancel message
        ESM.discord_bot.test_outbox.await_size(4)
      end
    end

    context "when the target is a partial server ID" do
      it "sends the message to the correct server ID" do
        execute!(
          arguments: {
            broadcast_to: server.server_id[(community.community_id.size + 1)..],
            message: "Hello world!"
          },
          prompt_response: "yes"
        )

        # 1: Preview Message
        # 2: Spacer
        # 3: Confirmation
        # 4: Success message
        # 5: Message to first user
        ESM.discord_bot.test_outbox.await_size(5)
      end
    end

    context "when the command is executed in a DM" do
      it "raises an exception" do
        execution_args = {
          channel_type: :dm,
          arguments: {broadcast_to: "all", message: "Hello world!"}
        }

        expect { execute!(**execution_args) }.to raise_error(
          ESM::Exception::CheckFailure,
          /this command can only be used in a discord server's \*\*text channel/i
        )
      end
    end
  end

  describe "#on_website_execute" do
    subject(:service_command) { execute_website!(arguments: {broadcast_to:, message:}) }

    let!(:second_server) { create(:server, community_id: community.id) }
    let(:message) { "Hello world!" }

    before do
      ESM::Test.skip_cooldown = true
      grant_command_access!(community, "broadcast")
    end

    context "when a single server is the target" do
      let(:broadcast_to) { server.server_id }

      before do
        create(:cooldown, command_name: "preferences", user:, community:, server:)
        create(:cooldown, command_name: "preferences", user: second_user, community:, server: second_server)
      end

      it "is expected to complete the row with the number of people it reached" do
        expect(service_command.status).to eq("completed")
        expect(service_command.result).to eq({recipients: 1})
      end

      # await_size only waits for a floor, so the exact size is what actually rules out the preview embed, the spacer
      # and the confirmation prompt that the Discord path sends alongside the delivery.
      it "is expected to message only that server's players, with no preview or confirmation" do
        service_command

        outbox = ESM.discord_bot.test_outbox
        outbox.await_size(1)

        expect(outbox.size).to eq(1)
        expect(outbox.destinations.map(&:name)).to contain_exactly(user.discord_username)
      end
    end

    context "when every server is the target" do
      let(:broadcast_to) { "all" }

      before do
        create(:cooldown, command_name: "preferences", user:, community:, server:)
        create(:cooldown, command_name: "preferences", user: second_user, community:, server: second_server)
      end

      it "is expected to reach the players of every server" do
        expect(service_command.result).to eq({recipients: 2})
      end
    end

    # The count the admin is shown has to be the count that gets messaged, and a player on several of a community's
    # servers is one Discord account either way.
    context "when a player has played on more than one of the targeted servers" do
      let(:broadcast_to) { "all" }

      before do
        create(:cooldown, command_name: "preferences", user:, community:, server:)
        create(:cooldown, command_name: "preferences", user:, community:, server: second_server)
      end

      it "is expected to count and message them once" do
        expect(service_command.result).to eq({recipients: 1})

        outbox = ESM.discord_bot.test_outbox
        outbox.await_size(1)

        expect(outbox.size).to eq(1)
      end
    end

    context "when the message is longer than Discord will render" do
      let(:broadcast_to) { "all" }
      let(:message) { "a" * 2001 }

      it "is expected to fail the row without messaging anyone" do
        expect(service_command.status).to eq("failed")
        expect(service_command.error_message).to be_present
        expect(ESM.discord_bot.test_outbox).to be_empty
      end
    end

    context "when the target server belongs to another community" do
      let(:other_community) { create(:community) }
      let(:broadcast_to) { create(:server, community: other_community).server_id }

      it "is expected to fail the row without messaging anyone" do
        expect(service_command.status).to eq("failed")
        expect(ESM.discord_bot.test_outbox).to be_empty
      end
    end
  end
end
