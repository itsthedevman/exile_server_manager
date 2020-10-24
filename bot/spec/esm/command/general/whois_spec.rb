# frozen_string_literal: true

describe ESM::Command::General::Whois, category: "command" do
  let!(:command) { ESM::Command::General::Whois.new }

  before :example do
    ESM::Test.skip_cooldown = true
  end

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
    expect(command.arguments.size).to eql(1)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:user) { ESM::Test.user }

    it "should run (mention)" do
      command_statement = command.statement(target: user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { response = command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      expect(response.fields).not_to be_empty
    end

    it "should run (steam_uid)" do
      command_statement = command.statement(target: user.steam_uid)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      expect(response.fields).not_to be_empty
    end

    it "should run (discord id)" do
      command_statement = command.statement(target: user.discord_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      expect(response.fields).not_to be_empty
    end

    it "should run (not registered)" do
      user.update(steam_uid: "")
      command_statement = command.statement(target: user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      expect(response.fields).not_to be_empty
    end

    it "should run (steam_uid/not registered)" do
      command_statement = command.statement(target: ESM::User::BryanV2::STEAM_UID)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)
      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      expect(response.fields).not_to be_empty
    end
  end
end
