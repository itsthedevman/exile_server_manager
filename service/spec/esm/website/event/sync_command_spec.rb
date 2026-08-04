# frozen_string_literal: true

describe ESM::Website::Event::SyncCommand do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }

  let(:command_class) { ESM::Command::Server::Me }
  let(:player_data) { {uid: user.steam_uid, name: "Player", locker: 25_000} }

  let(:event) { Datum.new(user:, community:, arguments: {server_id: server.server_id}) }

  subject(:sync_command) { described_class.new(event) }

  before do
    # Connectivity and the round-trip out to Arma belong to the command's own specs; what's under test here is
    # what the event layer does around them.
    allow_any_instance_of(command_class).to receive(:check_for_connected_server!)
    allow_any_instance_of(command_class).to receive(:query_exile_database!).and_return([player_data])
  end

  describe "#on_execution" do
    it "returns what the command replied with" do
      expect(sync_command.on_execution(command_class)).to eq(player_data)
    end

    # A command that never replies leaves nothing behind, and the caller renders its own empty state from the nil
    # rather than being handed a stand-in it would have to recognize.
    it "returns nil when the command never replies" do
      allow_any_instance_of(command_class).to receive(:on_website_execute)

      expect(sync_command.on_execution(command_class)).to be_nil
    end

    context "when the player is on cooldown for this command" do
      let!(:cooldown) do
        create(
          :cooldown,
          :active,
          command_name: command_class.command_name,
          user_id: user.id,
          community_id: community.id,
          server_id: server.id
        )
      end

      # Cooldowns pace a player's deliberate actions; a page fetching the data it needs to render is not one, and a
      # community that sets a long cooldown for Discord would otherwise make its own dashboard unreadable.
      it "answers anyway" do
        expect(sync_command.on_execution(command_class)).to eq(player_data)
      end

      it "leaves the cooldown untouched" do
        expect { sync_command.on_execution(command_class) }.not_to change { cooldown.reload.expires_at }
      end
    end

    # Only the cooldown is waived. Everything a command checks about who is asking still applies.
    context "when the player is not registered" do
      let!(:user) { create(:user, :unregistered) }

      it "raises the command's check failure" do
        expect { sync_command.on_execution(command_class) }.to raise_error(ESM::Exception::CheckFailure)
      end
    end
  end

  # #on_error is only ever reached through #on_execution's rescue, so both cases raise from inside the command.
  describe "#on_error" do
    before do
      allow_any_instance_of(command_class).to receive(:on_website_execute).and_raise(error)
    end

    # An application error is the command telling the player something. It carries its own copy, so it travels back
    # untouched for the caller to render.
    context "with an application error" do
      let(:error) { ESM::Exception::ExtensionError.new(["Something the player did"]) }

      it "raises it without logging" do
        expect(ESM.discord_bot).not_to receive(:log_error)

        expect { sync_command.on_execution(command_class) }.to raise_error(error)
      end
    end

    # Anything else is a bug. The async path would have carried it into the logs by way of its row; with no row to
    # settle, it gets logged here before it leaves.
    context "with any other error" do
      let(:error) { StandardError.new("something broke") }

      it "logs it and re-raises" do
        expect(ESM.discord_bot).to receive(:log_error).with(
          hash_including(event: event.arguments, message: error.inspect)
        )

        expect { sync_command.on_execution(command_class) }.to raise_error(error)
      end
    end
  end
end
