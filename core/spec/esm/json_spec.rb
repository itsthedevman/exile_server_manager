# frozen_string_literal: true

RSpec.describe ESM::JSON do
  describe ".parse" do
    it "parses valid JSON" do
      result = described_class.parse('{"key": "value", "number": 42}')

      expect(result).to be_a(Hash)
      expect(result[:key]).to eq("value")
      expect(result[:number]).to eq(42)
    end

    it "parses JSON arrays" do
      result = described_class.parse("[1, 2, 3]")

      expect(result).to be_an(Array)
      expect(result).to eq([1, 2, 3])
    end

    it "returns nil for invalid JSON" do
      expect(described_class.parse("not valid json")).to be_nil
      expect(described_class.parse("{broken")).to be_nil
    end

    it "returns nil for empty input" do
      expect(described_class.parse("")).to be_nil
    end

    it "handles nested structures" do
      json = '{"outer": {"inner": {"deep": true}}}'
      result = described_class.parse(json)

      expect(result[:outer][:inner][:deep]).to be(true)
    end
  end

  describe ".pretty_generate" do
    it "generates formatted JSON from a hash" do
      input = {key: "value", number: 42}
      result = described_class.pretty_generate(input)

      expect(result).to include("key")
      expect(result).to include("value")
      expect(result).to be_a(String)
    end

    it "accepts a JSON string and reformats it" do
      input = '{"compact":"json"}'
      result = described_class.pretty_generate(input)

      expect(result).to include("compact")
      expect(result).to be_a(String)
    end

    it "handles arrays" do
      input = [1, 2, 3]
      result = described_class.pretty_generate(input)

      expect(result).to be_a(String)
      expect(result).to include("1")
    end
  end
end
