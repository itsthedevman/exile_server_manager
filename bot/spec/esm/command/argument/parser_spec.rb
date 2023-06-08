# frozen_string_literal: true

describe ESM::Command::Argument::Parser do
  let!(:command) { ESM::Command::Test::PlayerCommand.new }

  describe "Parsing" do
    it "parses successfully" do
      argument = ESM::Command::Argument.new(:test, {regex: /test/, description: "d"})
      parser = described_class.new(argument)

      expect(parser.parse("foo test bar")).to eq(["test", "test"])
    end

    it "parses successfully" do
      argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d"})
      parser = described_class.new(argument)

      expect(parser.parse("12345")).to eq(["12345", "12345"])
    end
  end

  it "defaults" do
    argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d", default: "testing"})
    parser = described_class.new(argument)

    expect(parser.parse("")).to eq(["", "testing"])
  end

  describe "Type-casting" do
    it "parses string" do
      argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d"})
      parser = described_class.new(argument)

      expect(parser.parse("testing")).to eq(["testing", "testing"])
    end

    it "parses integer" do
      argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d", type: :integer})
      parser = described_class.new(argument)

      expect(parser.parse("1")).to eq(["1", 1])
    end

    it "parses float" do
      # container = container_klass.new\(command, \[\[(.+)\]\]\)
      argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d", type: :float})
      parser = described_class.new(argument)

      expect(parser.parse("2.5")).to eq(["2.5", 2.5])
    end

    it "parses json" do
      argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d", type: :json})
      parser = described_class.new(argument)

      _match, value = parser.parse('{ "foo": "bar" }')
      expect(value).to have_key(:foo)
      expect(value[:foo]).to eq("bar")
    end

    it "parses symbol" do
      argument = ESM::Command::Argument.new(:test, {regex: /.*/, description: "d", type: :symbol})
      parser = described_class.new(argument)

      expect(described_class.new(argument).parse("testing")).to eq(["testing", :testing])
    end
  end
end
