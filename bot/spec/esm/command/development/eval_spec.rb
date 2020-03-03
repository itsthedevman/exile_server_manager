# frozen_string_literal: true

describe ESM::Command::Development::Eval, category: "command" do
  let!(:command) { ESM::Command::Development::Eval.new }
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
    it "should return true" do
      event = CommandEvent.create("!eval true", user: user)
      expect(command.execute(event)).to eql("Input:\n```ruby\ntrue\n```\nOutput:\n```ruby\ntrue\n```")
    end

    it "should return 'test'" do
      event = CommandEvent.create("!eval 'test'", user: user)
      expect(command.execute(event)).to eql("Input:\n```ruby\n'test'\n```\nOutput:\n```ruby\ntest\n```")
    end

    it "should return 5" do
      event = CommandEvent.create("!eval 2 + 3", user: user)
      expect(command.execute(event)).to eql("Input:\n```ruby\n2 + 3\n```\nOutput:\n```ruby\n5\n```")
    end
  end
end
