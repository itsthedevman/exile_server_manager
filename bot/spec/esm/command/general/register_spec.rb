# frozen_string_literal: true

describe ESM::Command::General::Register, category: "command" do
  let!(:command) { ESM::Command::General::Register.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 0 argument" do
    expect(command.arguments.size).to eql(0)
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
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eql("Greetings #{user.mention}! My name is Exile Server Manager and I'm here to help make interacting with your character on a Exile server easier.\nIn order to use my commands, I'll need you to link your Steam account with your Discord account on my website.\nWhen you get logged into my website, please make sure to **double check your Discord account information** to ensure that you will be registering with the correct account.\n\nFeel free to head over to https://www.esmbot.com/register when you are ready.")
    end

    it "!register (Registered)" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      expect(ESM::Test.messages.size).to eql(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to eql("Hey #{user.mention}, it looks like you are already registered with me. You can view all of my commands using `#{command.prefix}help commands`.\nLooking for the registration link? It's https://www.esmbot.com/register")
    end
  end
end
