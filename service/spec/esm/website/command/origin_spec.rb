# frozen_string_literal: true

describe ESM::Website::Command::Origin do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }

  let(:service_command) do
    ESM::ServiceCommand.create!(
      user: user,
      server: server,
      community: community,
      idempotency_key: SecureRandom.uuid,
      command_name: "gamble",
      arguments: {},
      status: :pending
    )
  end

  subject(:origin) { described_class.new(service_command) }

  describe "#reply_error" do
    context "with a keyed CheckFailure" do
      let(:error) do
        ESM::Exception::CheckFailure.new(key: "command_errors.on_cooldown_time_left", user: user, time_left: "8 seconds")
      end

      it "fails the row, names the player by username, and strips markup" do
        origin.reply_error(error)
        service_command.reload

        expect(service_command.status).to eq("failed")
        expect(service_command.error_message).to include(user.username, "8 seconds")
        expect(service_command.error_message).not_to include("<@")
        expect(service_command.error_message).not_to include("**")
      end
    end

    context "when a _web copy variant exists" do
      let(:error) do
        ESM::Exception::CheckFailure.new(key: "command_errors.not_registered", user: user, full_username: user.distinct)
      end

      it "renders the web variant rather than the Discord copy" do
        origin.reply_error(error)

        expect(service_command.reload.error_message).to include("before you can run commands")
      end
    end

    context "with a literal extension error carrying a baked-in player token" do
      let(:error) do
        ESM::Exception::ExtensionError.new(["Hey #{user.mention}, you do not have enough **poptabs** in your `locker`"])
      end

      it "swaps the token for the username and strips markup" do
        origin.reply_error(error)
        message = service_command.reload.error_message

        expect(message).to include(user.username, "you do not have enough poptabs in your locker")
        expect(message).not_to include(user.mention)
        expect(message).not_to include("`")
      end
    end
  end

  describe "#from_website?" do
    it "is true for a website origin" do
      expect(origin.from_website?).to be(true)
    end
  end

  describe "#from_discord?" do
    it "is false for a website origin" do
      expect(origin.from_discord?).to be(false)
    end
  end
end
