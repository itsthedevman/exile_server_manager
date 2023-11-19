# frozen_string_literal: true

describe ESM::Command::General::Register, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    context "when the user is unregistered" do
      before do
        user.update!(steam_uid: "")
      end

      it "gives the user information about registering" do
        execute!

        embed = ESM::Test.messages.first.content

        # Docstring adds a newline to the end of the string. Rspec will fail the test but won't say why
        expectation = <<~STRING.chomp
          Greetings #{user.mention}!

          My name is Exile Server Manager and I'm here to help make interacting with your character on a Exile server easier. In order to use my commands, I'll need you to link your Steam account with your Discord account on my website; this will require you to authenticate with your Discord and Steam accounts.

          Before you sign into your Steam account, please double check the Discord account you are signed into as you may be signed into another account in your browser.
          **This Discord account is #{user.distinct}.**

          Once you're ready, please head over to https://www.esmbot.com/register to get started.
        STRING

        expect(embed.description).to match(expectation)
      end
    end

    context "when the user is registered" do
      it "gives the user the registration link" do
        execute!

        embed = ESM::Test.messages.first.content
        expect(embed.description).to eq(
          "Hey #{user.mention}, it looks like you are already registered with me. You can view all of my commands using `/help commands`.\nLooking for the registration link? It's https://www.esmbot.com/register"
        )
      end
    end
  end
end
