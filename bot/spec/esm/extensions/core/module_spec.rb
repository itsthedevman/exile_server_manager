# frozen_string_literal: true

describe Module do
  describe "#attr_predicate" do
    subject(:mock) { Mocks::AttrPredicateMock.new }

    it "defines predicates" do
      is_expected.to respond_to(:one?)
      is_expected.to respond_to(:two?)
      is_expected.to respond_to(:three?)
    end

    it "works with instance variables" do
      mock.one = 1

      expect(mock.one?).to be(true)
      expect(mock.two?).to be(false)
      expect(mock.three?).to be(true)
    end

    it "does not touch the singleton methods" do
      expect(Mocks::AttrPredicateMock).not_to respond_to(:one?)
      expect(Mocks::AttrPredicateMock).not_to respond_to(:two?)
      expect(Mocks::AttrPredicateMock).not_to respond_to(:three?)
    end
  end
end
