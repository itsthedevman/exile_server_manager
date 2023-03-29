# frozen_string_literal: true

describe ESM::Command do
  let(:event) { OpenStruct.new(channel: nil) }

  it "has commands" do
    ESM::Command.load
    expect(ESM.bot.commands).not_to be_blank
  end

  it "has cached the commands" do
    expect(ESM::Command.all).not_to be_empty
  end

  it "organizes by type" do
    %i[player admin].each do |type|
      expect(ESM::Command.by_type[type]).not_to be_empty
    end
  end

  describe "#include?" do
    it "has command" do
      expect(ESM::Command.include?("help")).to be(true)
    end

    it "does not have command" do
      expect(ESM::Command.include?("This command cannot exist")).to be(false)
    end
  end

  describe "#[]" do
    it "returns a command" do
      expect(ESM::Command["help"]).not_to be_nil
    end

    it "returns nil" do
      expect(ESM::Command["This command cannot exist"]).to be_nil
    end
  end
end
