# frozen_string_literal: true

describe ESM::Command::General::SteamUid, category: "command" do
  let!(:command) { ESM::Command::General::SteamUid.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 0 argument" do
    expect(command.arguments.size).to eq(0)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }

    it "!command_name argument" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      expect(ESM::Test.messages.size).to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eq("Hey #{user.mention}, your Steam UID is `#{user.steam_uid}`.")
    end
  end
end
