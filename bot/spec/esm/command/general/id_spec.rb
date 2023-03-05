# frozen_string_literal: true

describe ESM::Command::General::Id, category: "command" do
  let!(:command) { ESM::Command::General::Id.new }

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
    let!(:user) { ESM::Test.user }

    it "should return" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error

      response = ESM::Test.messages.first.second
      expect(response).not_to be_nil
      expect(response.description).to match(/community id is/i)
      expect(response.fields.size).to eq(1)
      expect(response.fields.first.name).to eq("Want to list all registered servers for this community?")
      expect(response.fields.first.value).to match(/~servers/i)
    end
  end
end
