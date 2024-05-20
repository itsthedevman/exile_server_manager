# frozen_string_literal: true

describe Discordrb::Channel do
  describe "TYPE_NAMES" do
    it "should return the correct names" do
      expect(Discordrb::Channel::TYPE_NAMES[0]).to eq(:text)
      expect(Discordrb::Channel::TYPE_NAMES[1]).to eq(:dm)
      expect(Discordrb::Channel::TYPE_NAMES[2]).to eq(:voice)
      expect(Discordrb::Channel::TYPE_NAMES[3]).to eq(:group)
      expect(Discordrb::Channel::TYPE_NAMES[4]).to eq(:category)
    end
  end
end
