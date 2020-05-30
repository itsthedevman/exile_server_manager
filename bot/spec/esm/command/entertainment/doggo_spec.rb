# frozen_string_literal: true

describe ESM::Command::Entertainment::Doggo, category: "command" do
  let!(:command) { ESM::Command::Entertainment::Doggo.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
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
    let!(:user) { ESM::Test.user }

    it "should return" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error
      response = ESM::Test.messages.second.second
      expect(response).not_to be_nil
      expect(response).to match(/\.jpg$|\.png$|\.gif$|\.jpeg$/i)
    end
  end
end
