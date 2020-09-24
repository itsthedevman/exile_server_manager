# frozen_string_literal: true

describe ESM::Cooldown do
  describe "#active?" do
    it "should be active (seconds)" do
      cooldown = build(:cooldown, :active)
      expect(cooldown.active?).to be(true)
    end

    it "should not be active (seconds)" do
      cooldown = build(:cooldown, :inactive)
      expect(cooldown.active?).to be(false)
    end

    it "should be active (times)" do
      cooldown = build(:cooldown, expires_at: nil, cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 2)
      expect(cooldown.active?).to be(true)
    end

    it "should not be active (times)" do
      cooldown = build(:cooldown, expires_at: nil, cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 0)
      expect(cooldown.active?).to be(false)

      cooldown = build(:cooldown, expires_at: nil, cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 1)
      expect(cooldown.active?).to be(false)
    end
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

  describe "#adjust_for_community_changes" do
    let(:community) { ESM::Test.community }
    let(:user) { ESM::Test.user }
    let!(:configuration) { community.command_configurations.where(command_name: "base").first }
    let!(:expires_at) { Time.now.utc + 1.day }
    let!(:cooldown_defaults) { { user_id: user.id, community_id: community.id, command_name: "base", expires_at: expires_at } }

    it "should not crash (no community ID)" do
      expect { create(:cooldown, cooldown_defaults.merge(community_id: nil, cooldown_type: configuration.cooldown_type, cooldown_quantity: configuration.cooldown_quantity)).reload }.not_to raise_error
    end

    it "should not change (seconds, no changes)" do
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: configuration.cooldown_type, cooldown_quantity: configuration.cooldown_quantity)).reload
      expect(cooldown.expires_at.to_s).to eql(expires_at.to_s)
    end

    it "should not change (times, no changes)" do
      configuration.update!(cooldown_type: "times", cooldown_quantity: 1)
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: configuration.cooldown_type, cooldown_quantity: configuration.cooldown_quantity)).reload
      expect(cooldown.expires_at.to_s).to eql(expires_at.to_s)
      expect(cooldown.cooldown_amount).to eql(0)
    end

    it "should reset (seconds -> times)" do
      configuration.update(cooldown_type: "times", cooldown_quantity: 1)
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 2)).reload
      expect(cooldown.expires_at.to_s).not_to eql(expires_at.to_s)
      expect(cooldown.cooldown_amount).to eql(0)
    end

    it "should reset (times -> seconds)" do
      configuration.update(cooldown_type: "seconds", cooldown_quantity: 2)
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "times", cooldown_quantity: 1)).reload
      expect(cooldown.expires_at.to_s).not_to eql(expires_at.to_s)
      expect(cooldown.cooldown_amount).to eql(0)
    end

    it "should not change (seconds, new value is greater than current)" do
      configuration.update(cooldown_type: "seconds", cooldown_quantity: 5)
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 2)).reload
      expect(cooldown.expires_at.to_s).to eql(expires_at.to_s)
    end

    # This test needs to use hard coded values because of maths
    describe "should change (new value is less than current)" do
      let!(:expires_at) { Time.parse("2040-01-01 00:00:00 UTC") }

      it "5 seconds to 2 seconds (compensated 3 seconds)" do
        configuration.update(cooldown_type: "seconds", cooldown_quantity: 2)
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 5, expires_at: expires_at)).reload
        expect(cooldown.expires_at.to_s).to eql("2039-12-31 23:59:57 UTC")
      end

      it "1 minute to 30 seconds (compensated 30 seconds)" do
        configuration.update(cooldown_type: "seconds", cooldown_quantity: 30)
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "minutes", cooldown_quantity: 1, expires_at: expires_at)).reload
        expect(cooldown.expires_at.to_s).to eql("2039-12-31 23:59:30 UTC")
      end

      it "1 hour to 15 seconds (compensated 59 minutes and 45 seconds)" do
        configuration.update(cooldown_type: "seconds", cooldown_quantity: 15)
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "hour", cooldown_quantity: 1, expires_at: expires_at)).reload
        expect(cooldown.expires_at.to_s).to eql("2039-12-31 23:00:15 UTC")
      end

      it "1 day to 2 minute (compensated 23 hours and 58 minutes" do
        configuration.update(cooldown_type: "minutes", cooldown_quantity: 2)
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "days", cooldown_quantity: 1, expires_at: expires_at)).reload
        expect(cooldown.expires_at.to_s).to eql("2039-12-31 00:02:00 UTC")
      end
    end
  end
end
