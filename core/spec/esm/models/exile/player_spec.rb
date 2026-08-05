# frozen_string_literal: true

RSpec.describe ESM::Exile::Player do
  # Neither predicate reads the server, so the instance cases build without one rather than paying for a record.
  def player_with(damage)
    described_class.new(server: nil, player: {damage:})
  end

  describe ".alive?" do
    it "is true for a player carrying a survivable amount of damage" do
      expect(described_class.alive?({damage: 0.25})).to be(true)
    end

    it "is false when Exile holds no player row at all" do
      expect(described_class.alive?({damage: nil})).to be(false)
    end

    it "is false for the glitched, unspawnable state" do
      expect(described_class.alive?({damage: 1})).to be(false)
    end
  end

  describe ".stuck?" do
    it "is true only for the glitched, unspawnable state" do
      expect(described_class.stuck?({damage: 1})).to be(true)
    end

    it "is false for an ordinary dead player, who has no row left to be stuck in" do
      expect(described_class.stuck?({damage: nil})).to be(false)
    end

    it "is false for a living player" do
      expect(described_class.stuck?({damage: 0.25})).to be(false)
    end
  end

  describe "#alive?" do
    it "is true for a living player" do
      expect(player_with(0.25).alive?).to be(true)
    end

    it "is false once the player row is gone" do
      expect(player_with(nil).alive?).to be(false)
    end
  end

  describe "#stuck?" do
    it "is true for the glitched state" do
      expect(player_with(1).stuck?).to be(true)
    end

    # normalize defaults a missing damage to 1, which is the very value that marks the glitched state. Settling the
    # predicate before that default runs is the only thing keeping every ordinary dead player from reading as stuck.
    it "reads the damage the server sent rather than the one normalize fills in" do
      expect(player_with(nil).stuck?).to be(false)
    end
  end
end
