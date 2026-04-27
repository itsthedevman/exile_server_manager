# frozen_string_literal: true

describe ESM::JSON do
  describe ".parse" do
    let!(:data) do
      {
        int: 1,
        float: 2.5,
        bool: true,
        array: [-1, 83_383.52_332, false, [], {}],
        hash: {foo: "bar"}
      }
    end

    it "parses the json as a Hash" do
      expect(described_class.parse(data.to_json)).to eq(data)
    end

    it "parses the JSON as an OpenStruct" do
      expectation = OpenStruct.new(
        int: 1,
        float: 2.5,
        bool: true,
        array: [-1, 83_383.52_332, false, [], OpenStruct.new],
        hash: OpenStruct.new(foo: "bar")
      )

      expect(described_class.parse(data.to_json).to_ostruct).to eq(expectation)
    end

    it "fails to parse and returns nil" do
      expect(described_class.parse("noop")).to be_nil
      expect(described_class.parse("{\"foo_bar':")).to be_nil
    end
  end
end
