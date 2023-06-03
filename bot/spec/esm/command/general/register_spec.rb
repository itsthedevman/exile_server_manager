# frozen_string_literal: true

describe ESM::Command::General::Register, category: "command" do
  let!(:command) { ESM::Command::General::Register.new }

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

    it "!register (Unregistered)" do
      user.update(steam_uid: "")

      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.first.second

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

    it "!register (Registered)" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eq("Hey #{user.mention}, it looks like you are already registered with me. You can view all of my commands using `#{command.prefix}help commands`.\nLooking for the registration link? It's https://www.esmbot.com/register")
    end
  end
end
