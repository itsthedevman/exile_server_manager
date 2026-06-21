# frozen_string_literal: true

require "rails_helper"

RSpec.describe TerritoriesHelper, type: :helper do
  describe "#pay_confirm_message" do
    it "names the price when the caller knows it" do
      expect(helper.pay_confirm_message("1,000 poptabs"))
        .to eq("Pay 1,000 poptabs from your locker now?")
    end

    it "falls back to a generic line when no price is given" do
      expect(helper.pay_confirm_message)
        .to eq("Pay this territory's protection from your locker now?")
    end
  end

  describe "#web_extension_message" do
    let(:user) do
      {
        username: "Bryan",
        discord_mention: "<@137709767954137088>",
        steam_uid: "76561198037177305"
      }.to_istruct
    end

    it "swaps a leading Discord mention for the player's name" do
      text = "Hey <@137709767954137088>, you do not have enough poptabs"

      expect(helper.web_extension_message(text, user))
        .to eq("Hey Bryan, you do not have enough poptabs")
    end

    it "swaps a mention woven mid-sentence" do
      text = "Not to worry you, <@137709767954137088>, but the flag has been stolen"

      expect(helper.web_extension_message(text, user))
        .to eq("Not to worry you, Bryan, but the flag has been stolen")
    end

    it "swaps a Steam UID for players with no linked Discord" do
      text = "Hey 76561198037177305, you do not have enough poptabs"

      expect(helper.web_extension_message(text, user))
        .to eq("Hey Bryan, you do not have enough poptabs")
    end

    it "drops bold and code markup" do
      text = "It costs **50** and you have **-50** for `kewgk`"

      expect(helper.web_extension_message(text, user))
        .to eq("It costs 50 and you have -50 for kewgk")
    end

    it "falls back to \"you\" when the player has no name" do
      nameless = {username: nil, discord_mention: "<@137709767954137088>", steam_uid: nil}.to_istruct
      text = "Hey <@137709767954137088>, you do not have enough poptabs"

      expect(helper.web_extension_message(text, nameless))
        .to eq("Hey you, you do not have enough poptabs")
    end
  end
end
