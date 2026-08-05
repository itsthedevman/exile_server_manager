# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlayersHelper, type: :helper do
  describe "#player_status_for" do
    it "reads a living player as alive" do
      expect(helper.player_status_for(alive: true, stuck: false).label).to eq("Alive")
    end

    it "reads an ordinary dead player as dead" do
      expect(helper.player_status_for(alive: false, stuck: false).label).to eq("Dead")
    end

    # The whole point of the third state: both are dead, but only one of them needs an admin.
    it "singles out the stuck player rather than folding them in with the dead" do
      expect(helper.player_status_for(alive: false, stuck: true).label).to eq("Stuck")
    end

    it "pairs every state with an icon so it survives being read in grayscale" do
      labels = [
        helper.player_status_for(alive: true, stuck: false),
        helper.player_status_for(alive: false, stuck: false),
        helper.player_status_for(alive: false, stuck: true)
      ]

      expect(labels.map(&:icon_class).uniq.size).to eq(3)
    end
  end

  describe "#player_row_status" do
    it "reads a row with survivable damage as alive" do
      expect(helper.player_row_status({damage: 0.25}).label).to eq("Alive")
    end

    it "reads a row with no player row behind it as dead" do
      expect(helper.player_row_status({damage: nil}).label).to eq("Dead")
    end

    it "reads a row at full damage as stuck" do
      expect(helper.player_row_status({damage: 1}).label).to eq("Stuck")
    end
  end

  describe "#player_row_stuck?" do
    it "is true only for a row Exile can't spawn" do
      expect(helper.player_row_stuck?({damage: 1})).to be(true)
    end

    it "is false for a dead row and a living one alike" do
      expect(helper.player_row_stuck?({damage: nil})).to be(false)
      expect(helper.player_row_stuck?({damage: 0.25})).to be(false)
    end
  end
end
