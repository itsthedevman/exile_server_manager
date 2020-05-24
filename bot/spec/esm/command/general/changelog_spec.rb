# frozen_string_literal: true

describe ESM::Command::General::Changelog, category: "command" do
  let!(:command) { ESM::Command::General::Changelog.new }

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
    let!(:user) { ESM::Test.user }

    it "!changelog" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error
      expect(ESM::Test.messages.size).not_to eql(0)
    end
  end
end
