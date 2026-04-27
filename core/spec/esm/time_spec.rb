# frozen_string_literal: true

require "timecop"

RSpec.describe ESM::Time do
  before do
    Time.zone = "UTC"
  end

  describe "Format constants" do
    it "defines TIME format" do
      expect(described_class::Format::TIME).to eq("%F at %I:%M %p UTC")
    end

    it "defines DATE format" do
      expect(described_class::Format::DATE).to eq("%F")
    end

    it "defines SQL_TIME format" do
      expect(described_class::Format::SQL_TIME).to eq("%Y-%m-%dT%X")
    end
  end

  describe ".parse" do
    it "parses a string time as UTC" do
      result = described_class.parse("2024-01-15 10:30:00")

      expect(result).to be_a(ActiveSupport::TimeWithZone)
      expect(result.zone).to eq("UTC")
      expect(result.year).to eq(2024)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
    end

    it "returns the input if already a TimeWithZone" do
      time = Time.zone.parse("2024-01-15 10:30:00")
      result = described_class.parse(time)

      expect(result).to eq(time)
      expect(result.object_id).to eq(time.object_id)
    end
  end

  describe ".current" do
    it "returns the current time in UTC" do
      Timecop.freeze(Time.utc(2024, 6, 15, 12, 0, 0)) do
        result = described_class.current

        expect(result.zone).to eq("UTC")
        expect(result.year).to eq(2024)
        expect(result.month).to eq(6)
        expect(result.day).to eq(15)
      end
    end
  end

  describe ".now" do
    it "returns Time.zone.now" do
      Timecop.freeze do
        expect(described_class.now).to eq(Time.zone.now)
      end
    end
  end

  describe ".singularize" do
    it "singularizes '1 seconds' to '1 second'" do
      expect(described_class.singularize("1 seconds")).to eq("1 second")
    end

    it "singularizes '1 minutes' to '1 minute'" do
      expect(described_class.singularize("1 minutes")).to eq("1 minute")
    end

    it "singularizes '1 hours' to '1 hour'" do
      expect(described_class.singularize("1 hours")).to eq("1 hour")
    end

    it "singularizes '1 days' to '1 day'" do
      expect(described_class.singularize("1 days")).to eq("1 day")
    end

    it "does not singularize plural amounts" do
      expect(described_class.singularize("2 seconds")).to eq("2 seconds")
      expect(described_class.singularize("10 minutes")).to eq("10 minutes")
    end

    it "handles mixed time strings" do
      expect(described_class.singularize("1 hours and 1 minutes")).to eq("1 hour and 1 minute")
    end
  end

  describe ".distance_of_time_in_words" do
    before do
      Timecop.freeze(Time.zone.parse("2024-01-15 12:00:00"))
    end

    after do
      Timecop.return
    end

    it "calculates distance to a future time" do
      future = Time.zone.parse("2024-01-15 12:05:00")
      result = described_class.distance_of_time_in_words(future)

      expect(result).to match(/minute/i)
    end

    it "calculates distance to a past time" do
      past = Time.zone.parse("2024-01-15 11:00:00")
      result = described_class.distance_of_time_in_words(past)

      expect(result).to match(/hour/i)
    end

    it "accepts a custom from_time" do
      to_time = Time.zone.parse("2024-01-15 14:00:00")
      from_time = Time.zone.parse("2024-01-15 12:00:00")
      result = described_class.distance_of_time_in_words(to_time, from_time: from_time)

      expect(result).to match(/hour/i)
    end
  end
end
