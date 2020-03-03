# frozen_string_literal: true

describe ESM::Cooldown do
  it "should be active" do
    cooldown = build(:cooldown, :active)
    expect(cooldown.active?).to be(true)
  end

  it "should not be active" do
    cooldown = build(:cooldown, :inactive)
    expect(cooldown.active?).to be(false)
  end

  it "should show time left" do
    # These will always be one second off.
    cooldown = build(:cooldown, :active)
    expect(cooldown.to_s).to eql("9 seconds")

    cooldown = build(:cooldown, :active, delay: 2.days)
    expect(cooldown.to_s).to eql("1 day, 23 hours, 59 minutes, and 59 seconds")
  end

  describe "Singular Times" do
    it "should be singlular (1 Second)" do
      cooldown = build(:cooldown, :active, delay: 2.seconds)
      expect(cooldown.to_s).to eql("1 second")
    end

    it "should be singlular (1 Minute)" do
      cooldown = build(:cooldown, :active, delay: (1.minute + 1.second))
      expect(cooldown.to_s).to eql("1 minute")
    end

    it "should be singlular (1 Hour)" do
      cooldown = build(:cooldown, :active, delay: (1.hour + 1.second))
      expect(cooldown.to_s).to eql("1 hour")
    end

    it "should be singlular (1 Day)" do
      cooldown = build(:cooldown, :active, delay: (1.day + 1.second))
      expect(cooldown.to_s).to eql("1 day")
    end

    it "should be singlular (1 Week)" do
      cooldown = build(:cooldown, :active, delay: (1.week + 1.second))
      expect(cooldown.to_s).to eql("1 week")
    end

    it "should be singlular (1 Month)" do
      cooldown = build(:cooldown, :active, delay: (1.month + 1.second))
      expect(cooldown.to_s).to eql("1 month")
    end

    it "should be singlular (1 Year)" do
      cooldown = build(:cooldown, :active, delay: (1.year + 1.second))
      expect(cooldown.to_s).to eql("1 year")
    end
  end

  describe "#reset!" do
    it "should reset" do
      cooldown = create(:cooldown, :active)
      expect(cooldown.active?).to be(true)

      cooldown.reset!
      expect(cooldown.active?).to be(false)
    end
  end
end
