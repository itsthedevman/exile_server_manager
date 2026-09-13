# frozen_string_literal: true

RSpec.describe CooldownsHelper, type: :helper do
  describe "#cooldown_time_left" do
    def uses_cooldown(amount:, quantity: 2)
      ESM::Cooldown.new(cooldown_type: "times", cooldown_quantity: quantity, cooldown_amount: amount)
    end

    # The row stores uses spent. Shown as is under the Remaining column, a spent allowance read as a full one.
    it "counts the uses a player has left, not the ones they have spent" do
      expect(helper.cooldown_time_left(uses_cooldown(amount: 0))).to eq("2 of 2 uses left")
      expect(helper.cooldown_time_left(uses_cooldown(amount: 1))).to eq("1 of 2 uses left")
      expect(helper.cooldown_time_left(uses_cooldown(amount: 2))).to eq("0 of 2 uses left")
    end

    # A community lowering the allowance below what a player already spent leaves more spent than allowed
    it "never counts below zero" do
      expect(helper.cooldown_time_left(uses_cooldown(amount: 3))).to eq("0 of 2 uses left")
    end

    it "shows the time left on a running clock" do
      cooldown = ESM::Cooldown.new(cooldown_type: "hours", cooldown_quantity: 2, expires_at: 2.hours.from_now)

      expect(helper.cooldown_time_left(cooldown)).to end_with("left")
    end

    it "calls a finished clock expired" do
      cooldown = ESM::Cooldown.new(cooldown_type: "hours", cooldown_quantity: 2, expires_at: 1.minute.ago)

      expect(helper.cooldown_time_left(cooldown)).to eq("Expired")
    end
  end
end
