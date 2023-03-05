# frozen_string_literal: true

describe Array do
  describe "#format" do
    it "should return a formatted string" do
      string =
        [1, true, ["hello"]].format do |item|
          expect(item).not_to be_nil
          item.to_s
        end

      expect(string).to eq("1true[\"hello\"]")
    end
  end

  describe "#total_size" do
    it "should add up all items (strings)" do
      expect(["foo", "bar", "test", "!@#${%^&*()}"].total_size).to eq(22)
    end
  end
end
