# frozen_string_literal: true

describe Discordrb::Channel do
  describe "TYPE_NAMES" do
    it "should return the correct names" do
      expect(Discordrb::Channel::TYPE_NAMES[0]).to eql(:text)
      expect(Discordrb::Channel::TYPE_NAMES[1]).to eql(:dm)
      expect(Discordrb::Channel::TYPE_NAMES[2]).to eql(:voice)
      expect(Discordrb::Channel::TYPE_NAMES[3]).to eql(:group)
      expect(Discordrb::Channel::TYPE_NAMES[4]).to eql(:category)
    end
  end
end
