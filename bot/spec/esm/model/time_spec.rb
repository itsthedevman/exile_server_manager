# frozen_string_literal: true

describe ESM::Time do
  let(:time_one) { "2020-01-15T02:11:55" }
  let(:time_two) { "2020-01-18T15:47:52" }

  describe "#singularize" do
    it "should have tests"
  end

  describe "#parse" do
    it "should parse" do
      expect(ESM::Time.parse(time_one).strftime(ESM::Time::Format::TIME)).to eql("2020-01-15 at 02:11:55 AM UTC")
      expect(ESM::Time.parse(time_two).strftime(ESM::Time::Format::TIME)).to eql("2020-01-18 at 03:47:52 PM UTC")
    end
  end
end
