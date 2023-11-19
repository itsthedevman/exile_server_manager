# frozen_string_literal: true

describe ESM::Command::My::SteamUid, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    it "!command_name argument" do
      execute!

      embed = ESM::Test.messages.first.content
      expect(embed.description).to eq("Hey #{user.mention}, your Steam UID is: ```#{user.steam_uid}```")
    end
  end
end
