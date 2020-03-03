# frozen_string_literal: true

describe ESM::Command::General::Help, category: "command" do
  let!(:command) { ESM::Command::General::Help.new }

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
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }

    it "should execute with default getting started" do
      # So we can test the response
      embed = nil

      event = CommandEvent.create("!help", user: user)
      expect { embed = command.execute(event) }.not_to raise_error

      expect(embed.title).to match(/my name is exile server manager/i)
      expect(embed.description).to eql(t("commands.help.getting_started.description"))
      expect(embed.fields.size).to eql(1)
      expect(embed.fields.first.name).to eql(t("commands.help.categories.name"))
      expect(embed.fields.first.value).to eql(t("commands.help.categories.value"))
    end

    it "should return a valid embed (commands)" do
      embed = nil

      event = CommandEvent.create("!help commands", user: user)
      expect { embed = command.execute(event) }.not_to raise_error
      expect(embed).not_to be_nil
    end

    it "should return a valid embed (command)" do
      embed = nil

      event = CommandEvent.create("!help help", user: user)
      expect { embed = command.execute(event) }.not_to raise_error
      expect(embed).not_to be_nil
    end

    it "should not show admin commands if in player mode"
  end
end
