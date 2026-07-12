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
end
