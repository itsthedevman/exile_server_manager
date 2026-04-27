# frozen_string_literal: true

describe ESM::Time do
  describe "#singularize" do
    it "makes the time singular" do
      expect(ESM::Time.singularize("1 days")).to eq("1 day")
      expect(ESM::Time.singularize("1 minute, 1 seconds")).to eq("1 minute, 1 second")
    end
  end

  describe "#parse" do
    it "parses" do
      time = "2022-12-10T21:02:45.380808500Z"
      expect(
        ESM::Time.parse(time).strftime(ESM::Time::Format::TIME)
      ).to eq("2022-12-10 at 09:02 PM UTC")

      time = "2020-01-15T02:11:55"
      expect(
        ESM::Time.parse(time).strftime(ESM::Time::Format::TIME)
      ).to eq("2020-01-15 at 02:11 AM UTC")

      time = "2020-01-18T15:47:52"
      expect(
        ESM::Time.parse(time).strftime(ESM::Time::Format::TIME)
      ).to eq("2020-01-18 at 03:47 PM UTC")
    end
  end
end
