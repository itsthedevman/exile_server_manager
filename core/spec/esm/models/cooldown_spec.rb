# frozen_string_literal: true

require "timecop"

RSpec.describe ESM::Cooldown do
  before do
    Time.zone = "UTC"
    Timecop.freeze(Time.zone.parse("1990-01-01"))
  end

  after do
    Timecop.return
  end

  describe "#active?" do
    it "is active (seconds)" do
      cooldown = build(:cooldown, :active)
      expect(cooldown.active?).to be(true)
    end

    it "is not active (seconds)" do
      cooldown = build(:cooldown, :inactive)
      expect(cooldown.active?).to be(false)
    end

    it "is active (times)" do
      cooldown = build(:cooldown, expires_at: nil, cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 2)
      expect(cooldown.active?).to be(true)
    end

    it "is not active (times) when amount is zero" do
      cooldown = build(:cooldown, expires_at: nil, cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 0)
      expect(cooldown.active?).to be(false)
    end

    it "is not active (times) when amount is less than quantity" do
      cooldown = build(:cooldown, expires_at: nil, cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 1)
      expect(cooldown.active?).to be(false)
    end
  end

  describe "#to_s" do
    it "shows time left" do
      cooldown = build(:cooldown, :active)
      expect(cooldown.to_s).to match(/less than|second/i)
    end

    it "shows longer time periods" do
      cooldown = build(:cooldown, :active, delay: 2.days)
      expect(cooldown.to_s).to match(/day/i)
    end

    context "singular time units" do
      it "shows seconds range" do
        cooldown = build(:cooldown, :active, delay: 2.seconds)
        expect(cooldown.to_s).to match(/second/i)
      end

      it "shows 1 minute" do
        cooldown = build(:cooldown, :active, delay: (1.minute + 1.second))
        expect(cooldown.to_s).to eq("1 minute")
      end

      it "shows about 1 hour" do
        cooldown = build(:cooldown, :active, delay: (1.hour + 1.second))
        expect(cooldown.to_s).to match(/1 hour/i)
      end

      it "shows 1 day" do
        cooldown = build(:cooldown, :active, delay: (1.day + 1.second))
        expect(cooldown.to_s).to eq("1 day")
      end

      it "shows days for 1 week" do
        cooldown = build(:cooldown, :active, delay: (1.week + 1.second))
        expect(cooldown.to_s).to match(/day/i)
      end

      it "shows about 1 month" do
        cooldown = build(:cooldown, :active, delay: (1.month + 1.second))
        expect(cooldown.to_s).to match(/1 month/i)
      end

      it "shows about 1 year" do
        cooldown = build(:cooldown, :active, delay: (1.year + 1.second))
        expect(cooldown.to_s).to match(/1 year/i)
      end
    end
  end

  describe "#reset!" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }
    let!(:user) { create(:user) }

    it "resets the cooldown" do
      cooldown = create(:cooldown, :active, user: user, server: server, community: community)
      expect(cooldown.active?).to be(true)

      cooldown.reset!
      expect(cooldown.active?).to be(false)
    end
  end

  describe "#update_expiry!" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }
    let!(:user) { create(:user) }

    it "accepts times (1.times, 2.times, etc.)" do
      cooldown = create(:cooldown, user: user, server: server, community: community, cooldown_amount: 0, cooldown_quantity: 1, cooldown_type: "times")

      cooldown.update_expiry!(nil, 1)
      expect(cooldown.cooldown_amount).to eq(1)
      expect(cooldown.active?).to be(true)

      cooldown.update_expiry!(nil, 5.times)
      expect(cooldown.cooldown_amount).to eq(2)
      expect(cooldown.cooldown_quantity).to eq(5)
      expect(cooldown.active?).to be(false)
    end

    it "accepts durations (1.second, 5.minutes, etc.)" do
      cooldown = create(:cooldown, :inactive, user: user, server: server, community: community)

      cooldown.update_expiry!(Time.current, 5.minutes)
      expect(cooldown.cooldown_quantity).to eq(5)
      expect(cooldown.cooldown_type).to eq("minutes")
      expect(cooldown.expires_at).to be_within(6.minutes).of(Time.current)
      expect(cooldown.active?).to be(true)
    end
  end

  describe "#reconcile_to!" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }
    let!(:user) { create(:user) }
    let(:expires_at) { Time.now.utc + 1.day }

    let(:cooldown_defaults) do
      {
        user_id: user.id,
        community_id: community.id,
        server_id: server.id,
        command_name: "player_command",
        expires_at: expires_at
      }
    end

    def configuration_for(cooldown_type:, cooldown_quantity:)
      build(
        :command_configuration,
        community: community,
        command_name: "player_command",
        cooldown_type: cooldown_type,
        cooldown_quantity: cooldown_quantity
      )
    end

    it "does not change when the configuration matches (seconds)" do
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 2))
      cooldown.reconcile_to!(configuration_for(cooldown_type: "seconds", cooldown_quantity: 2))
      expect(cooldown.expires_at.to_s).to eq(expires_at.to_s)
    end

    it "does not change when the configuration matches (times)" do
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "times", cooldown_quantity: 1, cooldown_amount: 0))
      cooldown.reconcile_to!(configuration_for(cooldown_type: "times", cooldown_quantity: 1))
      expect(cooldown.expires_at.to_s).to eq(expires_at.to_s)
      expect(cooldown.cooldown_amount).to eq(0)
    end

    it "resets when changing from seconds to times" do
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 2))
      cooldown.reconcile_to!(configuration_for(cooldown_type: "times", cooldown_quantity: 1))
      expect(cooldown.expires_at.to_s).not_to eq(expires_at.to_s)
      expect(cooldown.cooldown_amount).to eq(0)
    end

    it "resets when changing from times to seconds" do
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "times", cooldown_quantity: 1))
      cooldown.reconcile_to!(configuration_for(cooldown_type: "seconds", cooldown_quantity: 2))
      expect(cooldown.expires_at.to_s).not_to eq(expires_at.to_s)
      expect(cooldown.cooldown_amount).to eq(0)
    end

    it "does not extend when the new value is greater than current" do
      cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 2))
      cooldown.reconcile_to!(configuration_for(cooldown_type: "seconds", cooldown_quantity: 5))
      expect(cooldown.expires_at.to_s).to eq(expires_at.to_s)
    end

    context "when the new value is less than current" do
      let(:expires_at) { Time.parse("2040-01-01 00:00:00 UTC") }

      it "compensates from 5 seconds to 2 seconds" do
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "seconds", cooldown_quantity: 5))
        cooldown.reconcile_to!(configuration_for(cooldown_type: "seconds", cooldown_quantity: 2))
        expect(cooldown.expires_at.to_s).to eq("2039-12-31 23:59:57 UTC")
      end

      it "compensates from 1 minute to 30 seconds" do
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "minutes", cooldown_quantity: 1))
        cooldown.reconcile_to!(configuration_for(cooldown_type: "seconds", cooldown_quantity: 30))
        expect(cooldown.expires_at.to_s).to eq("2039-12-31 23:59:30 UTC")
      end

      it "compensates from 1 hour to 15 seconds" do
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "hours", cooldown_quantity: 1))
        cooldown.reconcile_to!(configuration_for(cooldown_type: "seconds", cooldown_quantity: 15))
        expect(cooldown.expires_at.to_s).to eq("2039-12-31 23:00:15 UTC")
      end

      it "compensates from 1 day to 2 minutes" do
        cooldown = create(:cooldown, cooldown_defaults.merge(cooldown_type: "days", cooldown_quantity: 1))
        cooldown.reconcile_to!(configuration_for(cooldown_type: "minutes", cooldown_quantity: 2))
        expect(cooldown.expires_at.to_s).to eq("2039-12-31 00:02:00 UTC")
      end
    end
  end

  describe ".reconcile_to (via a CommandConfiguration change)" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }
    let!(:user) { create(:user) }
    let(:expires_at) { Time.parse("2040-01-01 00:00:00 UTC") }

    let!(:configuration) do
      create(
        :command_configuration,
        community: community,
        command_name: "player_command",
        cooldown_type: "seconds",
        cooldown_quantity: 5
      )
    end

    let!(:cooldown) do
      create(
        :cooldown,
        user_id: user.id,
        community_id: community.id,
        server_id: server.id,
        command_name: "player_command",
        cooldown_type: "seconds",
        cooldown_quantity: 5,
        expires_at: expires_at
      )
    end

    it "heals affected cooldowns when the cooldown length changes" do
      configuration.update!(cooldown_quantity: 2)
      expect(cooldown.reload.expires_at.to_s).to eq("2039-12-31 23:59:57 UTC")
    end

    it "leaves cooldowns untouched when a non-cooldown attribute changes" do
      configuration.update!(enabled: false)
      expect(cooldown.reload.expires_at.to_s).to eq(expires_at.to_s)
    end

    it "does not touch cooldowns for a different command" do
      other = create(
        :cooldown,
        user_id: user.id,
        community_id: community.id,
        server_id: server.id,
        command_name: "other_command",
        cooldown_type: "seconds",
        cooldown_quantity: 5,
        expires_at: expires_at
      )

      configuration.update!(cooldown_quantity: 2)
      expect(other.reload.expires_at.to_s).to eq(expires_at.to_s)
    end
  end

  describe ".scope_for" do
    let!(:community) { create(:community) }
    let!(:server) { create(:server, community: community) }
    let!(:user) { create(:user) }

    it "keys on steam_uid for registration-gated commands" do
      cooldown = create(:cooldown, command_name: "gamble", steam_uid: user.steam_uid, community_id: community.id, server_id: server.id)

      scope = described_class.scope_for(command_name: "gamble", user: user, registered: true, community: community, server: server)
      expect(scope).to contain_exactly(cooldown)
    end

    it "keys on user_id for open commands" do
      cooldown = create(:cooldown, command_name: "help", user_id: user.id, community_id: community.id, server_id: server.id)

      scope = described_class.scope_for(command_name: "help", user: user, registered: false, community: community, server: server)
      expect(scope).to contain_exactly(cooldown)
    end

    it "does not match another player's cooldown" do
      create(:cooldown, command_name: "gamble", steam_uid: user.steam_uid, community_id: community.id, server_id: server.id)
      other_user = create(:user)

      scope = described_class.scope_for(command_name: "gamble", user: other_user, registered: true, community: community, server: server)
      expect(scope).to be_empty
    end
  end
end
