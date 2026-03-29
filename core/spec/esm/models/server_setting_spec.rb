# frozen_string_literal: true

RSpec.describe ESM::ServerSetting do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, :with_setting, community: community) }

  describe "CONFIG_ATTRIBUTES" do
    it "defines config attributes from config.yml" do
      expect(described_class::CONFIG_ATTRIBUTES).to include(:connection_uri)
      expect(described_class::CONFIG_ATTRIBUTES).to include(:log_level)
      expect(described_class::CONFIG_ATTRIBUTES).to include(:database_uri)
      expect(described_class::CONFIG_ATTRIBUTES).to include(:extdb_version)
    end
  end

  describe "CONFIG_DEFAULTS" do
    it "provides default values for config attributes" do
      expect(described_class::CONFIG_DEFAULTS[:log_level]).to eq("info")
      expect(described_class::CONFIG_DEFAULTS[:extdb_version]).to eq(3)
      expect(described_class::CONFIG_DEFAULTS[:number_locale]).to eq("en")
      expect(described_class::CONFIG_DEFAULTS[:exile_logs_search_days]).to eq(14)
    end

    it "is frozen" do
      expect(described_class::CONFIG_DEFAULTS).to be_frozen
    end
  end

  describe "default attribute values" do
    let(:setting) { server.server_setting }

    it "has gambling defaults" do
      expect(setting.gambling_locker_limit_enabled).to be(true)
      expect(setting.gambling_payout_base).to eq(95)
      expect(setting.gambling_modifier).to eq(1)
      expect(setting.gambling_win_percentage).to eq(35)
    end

    it "has logging defaults" do
      expect(setting.logging_exec).to be(true)
      expect(setting.logging_gamble).to be(false)
      expect(setting.logging_pay_territory).to be(true)
    end

    it "has territory defaults" do
      expect(setting.territory_payment_tax).to eq(0)
      expect(setting.territory_upgrade_tax).to eq(0)
      expect(setting.territory_price_per_object).to eq(10)
      expect(setting.territory_lifetime).to eq(7)
    end

    it "has server restart defaults" do
      expect(setting.server_restart_hour).to eq(3)
      expect(setting.server_restart_min).to eq(0)
    end
  end

  describe "#server_needs_restarted?" do
    let(:setting) { server.server_setting }

    it "returns false when only config attributes change" do
      setting.update!(extdb_conf_header_name: "custom_header")
      expect(setting.server_needs_restarted?).to be(false)
    end

    it "returns true when non-config attributes change" do
      setting.update!(gambling_win_percentage: 50)
      expect(setting.server_needs_restarted?).to be(true)
    end

    it "returns true when territory settings change" do
      setting.update!(territory_lifetime: 14)
      expect(setting.server_needs_restarted?).to be(true)
    end

    it "returns false when no changes" do
      setting.save!
      expect(setting.server_needs_restarted?).to be(false)
    end
  end

  describe "before_save :set_default_config_values" do
    let(:setting) { server.server_setting }

    it "sets config values to nil if they match defaults" do
      # Set to default value - should be cleared to nil
      setting.update!(extdb_conf_header_name: "exile")
      setting.reload
      expect(setting.extdb_conf_header_name).to be_nil
    end

    it "preserves non-default config values" do
      setting.update!(extdb_conf_header_name: "custom_header")
      setting.reload
      expect(setting.extdb_conf_header_name).to eq("custom_header")
    end
  end

  describe "associations" do
    it "belongs to a server" do
      setting = server.server_setting
      expect(setting.server).to eq(server)
    end
  end
end
