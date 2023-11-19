# frozen_string_literal: true

describe ESM::Exile::Territory do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:settings) { server.server_setting }
  let!(:territory_example) { TerritoryGenerator.generate.to_ostruct }
  let!(:wsc) { WebsocketClient.new(server) }

  # Not loaded every time so we can change the values of our example
  let(:territory) { ESM::Exile::Territory.new(server: server, territory: territory_example) }
  let(:same_level_territory) { ESM::Territory.where(territory_level: territory_example.level, server_id: server.id).first }
  let(:next_level_territory) { ESM::Territory.where(territory_level: territory_example.level + 1, server_id: server.id).first }

  before do
    wait_for { wsc.connected? }.to be(true)
  end

  after do
    wsc.disconnect!
  end

  describe "#id" do
    it "should return" do
      id = territory_example.esm_custom_id || territory_example.id

      expect(territory.id).to eq(id)
    end
  end

  describe "#name" do
    it "should return" do
      expect(territory.name).to eq(territory_example.territory_name)
    end
  end

  describe "#owner" do
    it "should return" do
      expect(territory.owner).to eq("#{territory_example.owner_name} (#{territory_example.owner_uid})")
    end
  end

  describe "#level" do
    it "should return" do
      expect(territory.level).to eq(territory_example.level)
    end
  end

  describe "#object_count" do
    it "should return" do
      expect(territory.object_count).to eq(territory_example.object_count)
    end
  end

  describe "#radius" do
    it "should return" do
      expect(territory.radius).to eq(territory_example.radius)
    end
  end

  describe "#flag_path" do
    it "should return" do
      expect(territory.flag_path).to eq(territory.send(:convert_flag_path, territory_example.flag_texture))
    end
  end

  describe "#stolen?" do
    it "should return" do
      expect(territory.stolen?).to eq(territory_example.flag_stolen)
    end
  end

  describe "#flag_status" do
    it "should return" do
      expect(territory.flag_status).to eq(territory_example.flag_stolen ? "Stolen!" : "Secure")
    end
  end

  describe "#last_paid_at" do
    it "should return" do
      expect(territory.last_paid_at).to eq(ESM::Time.parse(territory_example.last_paid_at))
    end
  end

  describe "#next_due_date" do
    it "should return" do
      next_due_date = ESM::Time.parse(territory_example.last_paid_at) + settings.territory_lifetime.days
      expect(territory.next_due_date).to eq(next_due_date)
    end
  end

  describe "#max_object_count" do
    it "should return" do
      expect(territory.max_object_count).to eq(same_level_territory.territory_object_count)
    end
  end

  describe "#renew_price" do
    it "should return the price (No tax)" do
      settings.update(territory_payment_tax: 0)

      expected_price = territory_example.level * territory_example.object_count * settings.territory_price_per_object
      expect(territory.renew_price).to eq("#{expected_price} poptabs")
    end

    it "should return the price (With tax)" do
      expected_price = territory_example.level * territory_example.object_count * settings.territory_price_per_object
      expected_price += (expected_price * (settings.territory_payment_tax.to_f / 100)).round

      expect(territory.renew_price).to eq("#{expected_price} poptabs (#{settings.territory_payment_tax}% tax added)")
    end
  end

  describe "#upgradeable?" do
    it "should return" do
      expect(territory.upgradeable?).to eq(next_level_territory.present?)
    end
  end

  describe "Requires Upgraded Territory" do
    before do
      territory_example.level = Faker::Number.between(from: 1, to: ESM::Territory.all.size - 2)
    end

    describe "#upgrade_level" do
      it "should return" do
        expect(territory.upgrade_level).to eq(next_level_territory.territory_level)
      end
    end

    describe "#upgrade_price" do
      it "should return the price (No tax)" do
        settings.update(territory_upgrade_tax: 0)

        expect(territory.upgrade_price).to eq("#{next_level_territory.territory_purchase_price} poptabs")
      end

      it "should return the price (With tax)" do
        expected_price = next_level_territory.territory_purchase_price
        expected_price += (expected_price * (settings.territory_upgrade_tax.to_f / 100)).round

        expect(territory.upgrade_price).to eq("#{expected_price} poptabs (#{settings.territory_upgrade_tax}% tax added)")
      end
    end

    describe "#upgrade_radius" do
      it "should return" do
        expect(territory.upgrade_radius).to eq(next_level_territory.territory_radius)
      end
    end

    describe "#upgrade_object_count" do
      it "should return" do
        expect(territory.upgrade_object_count).to eq(next_level_territory.territory_object_count)
      end
    end
  end

  describe "#moderators" do
    it "should return" do
      expect(territory.moderators).to eq(territory_example.moderators.map { |name, uid| "#{name} (#{uid})" })
    end
  end

  describe "#builders" do
    it "should return" do
      expect(territory.builders).to eq(territory_example.build_rights.map { |name, uid| "#{name} (#{uid})" })
    end
  end

  describe "#status_color" do
    it "should be green" do
      territory_example.flag_stolen = false
      territory_example.last_paid_at = ::Time.current.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.status_color).to eq(ESM::Color::Toast::GREEN)
    end

    it "should be yellow" do
      territory_example.flag_stolen = false
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 3).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.status_color).to eq(ESM::Color::Toast::YELLOW)
    end

    it "should be red (Stolen)" do
      territory_example.flag_stolen = true

      expect(territory.status_color).to eq(ESM::Color::Toast::RED)
    end

    it "should be red (Payment due)" do
      territory_example.flag_stolen = false
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 1).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.status_color).to eq(ESM::Color::Toast::RED)
    end
  end

  describe "#days_left_until_payment_due" do
    it "should return (Just Paid)" do
      last_paid_at = ::Time.current
      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.days_left_until_payment_due).to eq(settings.territory_lifetime)
    end

    it "should return (Needs payment)" do
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 3).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.days_left_until_payment_due).to eq(3)
    end

    it "should return (Payment ASAP)" do
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 1).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.days_left_until_payment_due).to eq(1)
    end
  end

  describe "#payment_reminder_message" do
    let(:time_left_message) do
      next_due_date = ESM::Time.parse(territory_example.last_paid_at) + settings.territory_lifetime.days

      "You have `#{ESM::Time.distance_of_time_in_words(next_due_date, precise: false)}` until your next payment is due."
    end

    it "should return a message (Just paid)" do
      last_paid_at = ::Time.current

      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)
      expect(territory.payment_reminder_message).to eq("")
    end

    it "should return a message (Needing to pay)" do
      last_paid_at = ::Time.current - (settings.territory_lifetime - 3).days
      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)
      expect(territory.payment_reminder_message).to eq(":warning: **You should consider making a base payment soon.**\n#{time_left_message}")
    end

    it "should return a message (pay ASAP)" do
      last_paid_at = ::Time.current - (settings.territory_lifetime - 1).days
      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)
      expect(territory.payment_reminder_message).to eq(":alarm_clock: **You should make a base payment ASAP to avoid losing your base!**\n#{time_left_message}")
    end
  end

  describe "#convert_flag_path" do
    let(:base_path) { "https://exile-server-manager.s3.amazonaws.com/flags" }
    let(:default_flag) { "#{base_path}/flag_white_co.jpg" }

    it "should parse arma path" do
      expect(territory.send(:convert_flag_path, "\\A3\\Data_F\\Flags\\flag_us_co.paa")).to eq("#{base_path}/flag_us_co.jpg")
    end

    it "should parse exile mod path" do
      expect(territory.send(:convert_flag_path, "exile_assets\\texture\\flag\\flag_misc_knuckles_co.paa")).to eq("#{base_path}/flag_misc_knuckles_co.jpg")
    end

    it "should return default" do
      expect(territory.send(:convert_flag_path, "")).to eq(default_flag)
      expect(territory.send(:convert_flag_path, "foo_bar_flag")).to eq(default_flag)
      expect(territory.send(:convert_flag_path, "\\A3\\SomeDirectory\\flag_something.paa")).to eq(default_flag)
    end
  end
end
