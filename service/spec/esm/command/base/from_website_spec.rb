# frozen_string_literal: true

RSpec.describe ESM::Command::Base, "#from_website!" do
  include_context "command" do
    let!(:command_class) { ESM::Command::Test::PlayerCommand }
  end

  let(:replies) { [] }
  let(:reply_sink) { ->(payload) { replies << payload } }

  let(:website_command) do
    origin = ESM::Website::Command::Origin.new(
      user: user,
      community: community,
      reply_sink: reply_sink
    )
    command_class.new(origin: origin)
  end

  it "executes on_execute and returns its result" do
    expect(website_command.from_website!).to eq("on_execute")
  end

  it "routes #reply through the origin's reply_sink" do
    website_command.reply("hello website")
    expect(replies).to eq([{description: "hello website"}])
  end

  context "when the command is text-only" do
    let!(:command_class) { ESM::Command::Test::TextChannelCommand }

    it "skips check_for_text_only! and runs anyway" do
      expect { website_command.from_website! }.not_to raise_error
    end
  end

  context "when the command is dm-only" do
    let!(:command_class) { ESM::Command::Test::DirectMessageCommand }

    it "skips check_for_dm_only! and runs anyway" do
      expect { website_command.from_website! }.not_to raise_error
    end
  end

  context "when the user is unregistered" do
    let!(:user) do
      create(:user, :unregistered, :with_discord_member, discord_user: discord_user, discord_server: discord_server)
    end

    it "still raises CheckFailure for registration" do
      expect { website_command.from_website! }.to raise_error(ESM::Exception::CheckFailure) do |error|
        expect(error.data.description).to match(/link your steam account/i)
      end
    end
  end
end
