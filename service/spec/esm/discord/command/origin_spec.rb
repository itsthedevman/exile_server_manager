# frozen_string_literal: true

RSpec.describe ESM::Discord::Command::Origin do
  let!(:user) { create(:user) }

  subject(:origin) { described_class.new(user: user) }

  describe "#from_discord?" do
    it "is true for a discord origin" do
      expect(origin.from_discord?).to be(true)
    end
  end

  describe "#from_website?" do
    it "is false for a discord origin" do
      expect(origin.from_website?).to be(false)
    end
  end
end
