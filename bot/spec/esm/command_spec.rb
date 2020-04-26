# frozen_string_literal: true

describe ESM::Command do
  let(:event) { OpenStruct.new(channel: nil) }

  it "should have commands" do
    expect(ESM.bot.commands).not_to be_blank
  end

  it "should format result (String)" do
    expect(ESM::Command.send(:send_result, "Foobar", event)).to eql("Foobar")
  end

  it "should format result (ESM Error 1)" do
    result = ESM::Command.send(:send_result, ESM::Exception::Error.new("Something bad happened!"), event)

    expect(result).to eql("Something bad happened!")
  end

  it "should format result (ESM Error 2)" do
    result = ESM::Command.send(:send_result, ESM::Exception::DuplicateCommand.new("Something bad happened!"), event)

    expect(result).to eql("Something bad happened!")
  end

  it "should format result (System Exception)" do
    expectation = I18n.t("exceptions.system", message: "Something bad happened!")
    result = ESM::Command.send(:send_result, ::Exception.new("Something bad happened!"), event)

    expect(result).to eql(expectation)
  end

  it "should have cached the commands" do
    expect(ESM::Command.all).not_to be_empty
  end

  it "should organize by category" do
    ESM::Command::CATEGORIES.each do |category|
      expect(ESM::Command.by_category.respond_to?(category.to_sym)).to be(true)
      expect(ESM::Command.by_category[category]).not_to be_empty
    end
  end

  it "should organize by type" do
    %w[player admin].each do |type|
      expect(ESM::Command.by_type.respond_to?(type.to_sym)).to be(true)
      expect(ESM::Command.by_type[type]).not_to be_empty
    end
  end

  describe "#include?" do
    it "should have command" do
      expect(ESM::Command.include?("help")).to be(true)
    end

    it "should not have command" do
      expect(ESM::Command.include?("This command cannot exist")).to be(false)
    end
  end

  describe "#[]" do
    it "should return a command" do
      expect(ESM::Command["help"]).not_to be_nil
    end

    it "should return nil" do
      expect(ESM::Command["This command cannot exist"]).to be_nil
    end
  end

  describe "#create_configurations_for_community" do
    it "should create configurations based off commands" do
      community = ESM::Test.community
      ESM::CommandConfiguration.where(community_id: community.id).in_batches(of: 10_000).destroy_all

      ESM::Command.create_configurations_for_community(community)
      community.reload
      expect(community.command_configurations.size).to eql(ESM::Command.all.size)

      ESM::Command.all.each do |command|
        expect(ESM::CommandConfiguration.where(community_id: community.id, command_name: command.name).any?).to be(true)
      end
    end
  end
end
