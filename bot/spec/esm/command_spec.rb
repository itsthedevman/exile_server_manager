# frozen_string_literal: true

describe ESM::Command do
  let(:event) { OpenStruct.new(channel: nil) }

  it "should have commands" do
    expect(ESM.bot.commands).not_to be_blank
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
end
