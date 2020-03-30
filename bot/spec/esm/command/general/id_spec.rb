# frozen_string_literal: true

describe ESM::Command::General::Id, category: "command" do
  let!(:command) { ESM::Command::General::Id.new }

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
    let!(:user) { ESM::Test.user }

    it "should return" do
      request = nil
      event = CommandEvent.create("!id", user: user, channel_type: :text)

      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      expect(request.description).to match(/community id is/i)
      expect(request.fields.size).to eql(1)
      expect(request.fields.first.name).to eql("Want to list all registered servers for this community?")
      expect(request.fields.first.value).to match(/~servers/i)
    end
  end
end
