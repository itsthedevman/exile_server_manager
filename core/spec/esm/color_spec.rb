# frozen_string_literal: true

RSpec.describe ESM::Color do
  describe "ALL" do
    it "contains BLUE and RED" do
      expect(described_class::ALL).to include(described_class::BLUE)
      expect(described_class::ALL).to include(described_class::RED)
    end

    it "is frozen" do
      expect(described_class::ALL).to be_frozen
    end
  end

  describe "color constants" do
    it "defines BLUE as a hex color" do
      expect(described_class::BLUE).to eq("#1e354d")
    end

    it "defines RED as a hex color" do
      expect(described_class::RED).to eq("#ce2d4e")
    end
  end

  describe ".random" do
    it "returns a color from the combined pool" do
      all_colors = described_class::ALL + described_class::Toast::ALL
      100.times do
        expect(all_colors).to include(described_class.random)
      end
    end
  end

  describe "Toast module" do
    describe "ALL" do
      it "contains multiple toast colors" do
        expect(described_class::Toast::ALL.size).to be >= 10
      end

      it "is frozen" do
        expect(described_class::Toast::ALL).to be_frozen
      end
    end

    describe "color constants" do
      it "defines standard toast colors" do
        expect(described_class::Toast::RED).to eq("#c62551")
        expect(described_class::Toast::BLUE).to eq("#3ed3fb")
        expect(described_class::Toast::GREEN).to eq("#9fde3a")
        expect(described_class::Toast::YELLOW).to eq("#deca39")
        expect(described_class::Toast::WHITE).to eq("#ffffff")
      end

      it "defines additional toast colors" do
        expect(described_class::Toast::ORANGE).to eq("#c64a25")
        expect(described_class::Toast::PURPLE).to eq("#793ade")
        expect(described_class::Toast::PINK).to eq("#de3a9f")
      end
    end

    describe ".to_h" do
      it "returns a hash of color names to hex values" do
        result = described_class::Toast.to_h

        expect(result).to be_a(Hash)
        expect(result[:red]).to eq("#c62551")
        expect(result[:blue]).to eq("#3ed3fb")
        expect(result[:green]).to eq("#9fde3a")
      end

      it "uses lowercase symbol keys" do
        result = described_class::Toast.to_h

        result.keys.each do |key|
          expect(key).to be_a(Symbol)
          expect(key.to_s).to eq(key.to_s.downcase)
        end
      end

      it "excludes ALL from the hash" do
        result = described_class::Toast.to_h

        expect(result).not_to have_key(:all)
        expect(result).not_to have_key(:ALL)
      end
    end
  end
end
