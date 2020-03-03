# frozen_string_literal: true

describe OpenStruct do
  describe "#blank?" do
    it "should be blank" do
      expect(OpenStruct.new.blank?).to be(true)
    end

    it "should not be blank" do
      expect(OpenStruct.new(foo: "bar").blank?).to be(false)
    end
  end
end
