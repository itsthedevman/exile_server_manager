# frozen_string_literal: true

describe Integer do
  describe "#to_poptab" do
    it "should convert" do
      expect(150_220.to_poptab).to eq("150,220 poptabs")
    end

    it "should be singular" do
      expect(1.to_poptab).to eq("1 poptab")
    end
  end

  describe "#to_readable" do
    it "should convert" do
      expect(1_983_434_552.to_readable).to eq("1,983,434,552")
    end
  end
end
