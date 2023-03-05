# frozen_string_literal: true

describe ESM::Command::Argument::Parser do
  let!(:container_klass) { ESM::Command::ArgumentContainer }

  describe "Parsing" do
    it "1" do
      container = container_klass.new([[:test, {regex: /test/, description: "d"}]])
      argument = container.first
      parser = described_class.new(argument, "test").parse!
      expect(parser.value).to eq("test")
    end

    it "2" do
      container = container_klass.new([[:test, {regex: /.*/, description: "d"}]])
      argument = container.first

      parser = described_class.new(argument, "12345").parse!
      expect(parser.value).to eq("12345")
    end
  end

  it "should default" do
    container = container_klass.new([[:test, {regex: /.*/, description: "d", default: "testing"}]])
    argument = container.first

    parser = described_class.new(argument, "").parse!
    expect(parser.value).to eq("testing")
  end

  describe "Type-casting" do
    it "should be string" do
      container = container_klass.new([[:test, {regex: /.*/, description: "d"}]])
      argument = container.first

      parser = described_class.new(argument, "testing").parse!
      expect(parser.value).to eq("testing")
    end

    it "should be integer" do
      container = container_klass.new([[:test, {regex: /.*/, description: "d", type: :integer}]])
      argument = container.first

      parser = described_class.new(argument, "1").parse!
      expect(parser.value).to eq(1)
    end

    it "should be float" do
      container = container_klass.new([[:test, {regex: /.*/, description: "d", type: :float}]])
      argument = container.first

      parser = described_class.new(argument, "2.5").parse!
      expect(parser.value).to eq(2.5)
    end

    it "should be json" do
      container = container_klass.new([[:test, {regex: /.*/, description: "d", type: :json}]])
      argument = container.first

      parser = described_class.new(argument, '{ "foo": "bar" }').parse!
      expect(parser.value).to have_key(:foo)
      expect(parser.value[:foo]).to eq("bar")
    end

    it "should be symbol" do
      container = container_klass.new([[:test, {regex: /.*/, description: "d", type: :symbol}]])
      argument = container.first

      parser = described_class.new(argument, "testing").parse!
      expect(parser.value).to eq(:testing)
    end
  end
end
