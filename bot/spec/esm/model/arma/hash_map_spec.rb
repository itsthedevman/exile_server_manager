# frozen_string_literal: true

describe ESM::Arma::HashMap, v2: true do
  describe ".new" do
    it "normalizes (Input is String)" do
      input = <<~STRING
        [
          ["key_1", "string value"],
          ["key_2", 1],
          ["key_3", 2.5],
          ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
          ["key_5", [["key_6", true], ["key_7", false]]]
        ]
      STRING

      expectation = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], {eight: false}],
        key_5: {key_6: true, key_7: false}
      }.with_indifferent_access

      hash_map = described_class.new(input)
      expect(hash_map).to eq(expectation)
    end

    it "normalizes (Input is Array)" do
      input = [
        ["key_1", "string value"],
        ["key_2", 1],
        ["key_3", 2.5],
        ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
        ["key_5", {key_6: true, key_7: false}]
      ]

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], {eight: false}],
        key_5: {key_6: true, key_7: false}
      }.with_indifferent_access

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end

    it "normalizes (Input is OpenStruct)" do
      input = OpenStruct.new(
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: {key_6: true, key_7: false}
      )

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], {eight: false}],
        key_5: {key_6: true, key_7: false}
      }.with_indifferent_access

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end

    it "normalizes (Input is Hash)" do
      input = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: [{key_6: true, key_7: false}, true],
        key_6: :symbol
      }

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], {eight: false}],
        key_5: [{key_6: true, key_7: false}, true],
        key_6: "symbol"
      }.with_indifferent_access

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end
  end

  describe "#to_a" do
    it "converts" do
      input = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], {eight: false}],
        key_5: [{key_6: true, key_7: false}, true]
      }

      expected = [
        ["key_1", "string value"],
        ["key_2", 1],
        ["key_3", 2.5],
        ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
        ["key_5", [[["key_6", true], ["key_7", false]], true]]
      ]

      hash_map = described_class.new(input)

      expect(hash_map.to_a).to eq(expected)
    end
  end

  describe "#to_json" do
    it "converts" do
      input = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], {eight: false}],
        key_5: [{key_6: true, key_7: false}, true]
      }

      expected = [
        ["key_1", "string value"],
        ["key_2", 1],
        ["key_3", 2.5],
        ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
        ["key_5", [[["key_6", true], ["key_7", false]], true]]
      ].to_json

      hash_map = described_class.new(input)

      expect(hash_map.to_json).to eq(expected)
    end
  end

  describe "#valid_hash_structure?" do
    let!(:hash) { described_class.new }

    it "is valid (Key value pairs)" do
      input = [["key_1", "value_1"], ["key_2", 2], ["key_3", "value_3"]]
      expect(hash.send(:valid_hash_structure?, input)).to be(true)
    end

    it "is not valid (Keys and values)" do
      input = [["key_1", "key_2", "key_3"], ["value_1", "value_2", "value_3"]]
      expect(hash.send(:valid_hash_structure?, input)).to be(false)
    end

    it "is not valid (Array of hash structures)" do
      input = [[["key_1", "value_1"], ["key_2", 2], ["key_3", "value_3"]], [["key_1", "value_1"], ["key_2", 2], ["key_3", "value_3"]]]
      expect(hash.send(:valid_hash_structure?, input)).to be(false)
    end
  end
end
