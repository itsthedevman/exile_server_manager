# frozen_string_literal: true

describe ESM::Command::Server::Broadcast, category: "command" do
  include_context "command"
  include_examples "validate_command"

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
        wait_for { ESM::Test.messages.size }.to eq(5)
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
        wait_for { ESM::Test.messages.size }.to eq(6)
      end
    end

    context "when the target is omitted" do
      it "sends a preview of the message" do
        execute!(arguments: {message: "Hello world!"})

        # 1: Preview Message
        wait_for { ESM::Test.messages.size }.to eq(1)
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
        wait_for { ESM::Test.messages.size }.to eq(4)
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
        wait_for { ESM::Test.messages.size }.to eq(5)
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
end
