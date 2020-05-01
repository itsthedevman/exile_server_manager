# frozen_string_literal: true

describe ESM::Command::Development::Say, category: "command" do
  let!(:command) { ESM::Command::Development::Say.new }
  let!(:community) { create(:esm_community) }
  let!(:server) { create(:esm_malden, community_id: community.id) }
  let!(:user) { create(:esm_dev) }

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
    it "should repeat back argument" do
      command_statement = command.statement(text: "Hello World")
      event = CommandEvent.create(command_statement, user: user)
      expect(command.execute(event)).to eql("Hello World")
    end
  end
end
