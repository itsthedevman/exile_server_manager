# frozen_string_literal: true

describe ESM::Color do
  describe "#colors" do
    it "should return all colors" do
      colors = ESM::Color.colors

      %i[BLUE RED].each do |color|
        color = ESM::Color.const_get(color)
        expect(colors).to include(color)
      end
    end
  end

  describe "#random" do
    it "should return a random color" do
      color = ESM::Color.random
      expect(color).to be_an(String)
    end
  end
end

describe ESM::Color::Toast do
  describe "#colors" do
    it "should return all colors" do
      colors = ESM::Color::Toast.colors

      %i[RED BLUE GREEN YELLOW ORANGE PURPLE PINK WHITE].each do |color|
        color = ESM::Color::Toast.const_get(color)
        expect(colors).to include(color)
      end
    end
  end
end
