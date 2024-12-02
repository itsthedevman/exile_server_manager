# frozen_string_literal: true

describe ESM::Exile::Territory, v2: true do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server(for: community, traits: [:v2, :with_territories]) }
  let!(:settings) { server.server_setting }

  let!(:territory_example) do
    owner_uid = ESM::Test.steam_uid
    moderator_uids = Array.new(2) { ESM::Test.steam_uid }
    builder_uids = Array.new(2) { ESM::Test.steam_uid }

    create(
      :exile_territory,
      owner_uid: owner_uid,
      moderators: [owner_uid] + moderator_uids,
      build_rights: [owner_uid] + moderator_uids + builder_uids,
      level: Faker::Number.between(from: 0, to: 3),
      server_id: server.id
    )
  end

  # Not loaded every time so we can change the values of our example
  let(:territory) { ESM::Exile::Territory.new(server: server, territory: territory_example.to_h) }

  let(:same_level_territory) do
    server.territories.where(territory_level: territory_example.level).first
  end

  let(:next_level_territory) do
    server.territories.where(territory_level: territory_example.level + 1).first
  end

  describe "#id" do
    it "is expected to return the value" do
      id = territory_example.esm_custom_id || territory_example.encoded_id

      expect(territory.id).to eq(id)
    end
  end

  describe "#name" do
    it "is expected to return the value" do
      expect(territory.name).to eq(territory_example.territory_name)
    end
  end

  describe "#owner" do
    it "is expected to return the value" do
      expect(territory.owner).to eq("#{territory_example.owner_name} (#{territory_example.owner_uid})")
    end
  end

  describe "#level" do
    it "is expected to return the value" do
      expect(territory.level).to eq(territory_example.level)
    end
  end

  describe "#object_count" do
    it "is expected to return the value" do
      expect(territory.object_count).to eq(territory_example.object_count)
    end
  end

  describe "#radius" do
    it "is expected to return the value" do
      expect(territory.radius).to eq(territory_example.radius)
    end
  end

  describe "#flag_path" do
    it "is expected to return the value" do
      expect(territory.flag_path).to eq(
        territory.send(:convert_flag_path, territory_example.flag_texture)
      )
    end
  end

  describe "#stolen?" do
    it "is expected to return the value" do
      expect(territory.stolen?).to eq(territory_example.flag_stolen)
    end
  end

  describe "#flag_status" do
    it "is expected to return the value" do
      expect(territory.flag_status).to eq(territory_example.flag_stolen ? "Stolen!" : "Secure")
    end
  end

  describe "#last_paid_at" do
    it "is expected to return the value" do
      expect(territory.last_paid_at.strftime(ESM::Time::Format::TIME)).to eq(
        territory_example.last_paid_at.strftime(ESM::Time::Format::TIME)
      )
    end
  end

  describe "#next_due_date" do
    it "is expected to return the value" do
      next_due_date = territory_example.last_paid_at + settings.territory_lifetime.days

      expect(territory.next_due_date.strftime(ESM::Time::Format::TIME)).to eq(
        next_due_date.strftime(ESM::Time::Format::TIME)
      )
    end
  end

  describe "#max_object_count" do
    it "is expected to return the value" do
      expect(territory.max_object_count).to eq(same_level_territory.territory_object_count)
    end
  end

  describe "#renew_price" do
    it "is expected to return the value the price (No tax)" do
      settings.update(territory_payment_tax: 0)

      expected_price = territory_example.level *
        territory_example.object_count *
        settings.territory_price_per_object

      expect(territory.renew_price).to eq("#{expected_price.to_delimitated_s} poptabs")
    end

    it "is expected to return the value the price (With tax)" do
      expected_price = territory_example.level *
        territory_example.object_count *
        settings.territory_price_per_object

      expected_price += (expected_price * (settings.territory_payment_tax.to_f / 100)).round

      expect(territory.renew_price).to eq(
        "#{expected_price.to_delimitated_s} poptabs (#{settings.territory_payment_tax}% tax added)"
      )
    end
  end

  describe "#upgradeable?" do
    it "is expected to return the value" do
      expect(territory.upgradeable?).to eq(next_level_territory.present?)
    end
  end

  describe "Requires Upgraded Territory" do
    before do
      territory_example.level = Faker::Number.between(from: 1, to: ESM::Territory.all.size - 2)
    end

    describe "#upgrade_level" do
      it "is expected to return the value" do
        expect(territory.upgrade_level).to eq(next_level_territory.territory_level)
      end
    end

    describe "#upgrade_price" do
      it "is expected to return the value the price (No tax)" do
        settings.update(territory_upgrade_tax: 0)

        expect(territory.upgrade_price).to eq(
          "#{next_level_territory.territory_purchase_price.to_delimitated_s} poptabs"
        )
      end

      it "is expected to return the value the price (With tax)" do
        expected_price = next_level_territory.territory_purchase_price
        expected_price += (expected_price * (settings.territory_upgrade_tax.to_f / 100)).round

        expect(territory.upgrade_price).to eq(
          "#{expected_price.to_delimitated_s} poptabs (#{settings.territory_upgrade_tax}% tax added)"
        )
      end
    end

    describe "#upgrade_radius" do
      it "is expected to return the value" do
        expect(territory.upgrade_radius).to eq(next_level_territory.territory_radius)
      end
    end

    describe "#upgrade_object_count" do
      it "is expected to return the value" do
        expect(territory.upgrade_object_count).to eq(next_level_territory.territory_object_count)
      end
    end
  end

  describe "#moderators" do
    let(:moderators) do
      territory_example.moderators_as_hash.reject do |hash|
        territory_example.owner_uid == hash[:uid]
      end
    end

    before do
      territory_example.moderators.each do |uid|
        create(:exile_account, uid:) if ESM::ExileAccount.find_by(uid:).nil?
      end
    end

    it "is expected to return the value" do
      expect(territory.moderators).to eq(
        moderators.join_map("\n") { |hash| "#{hash[:name]} (#{hash[:uid]})" }
      )
    end
  end

  describe "#builders" do
    let(:builders) do
      territory_example.builders_as_hash.reject do |hash|
        territory_example.owner_uid == hash[:uid] ||
          territory_example.moderators.include?(hash[:uid])
      end
    end

    before do
      territory_example.build_rights.each do |uid|
        create(:exile_account, uid:) if ESM::ExileAccount.find_by(uid:).nil?
      end
    end

    it "is expected to return the value" do
      expect(territory.builders).to eq(
        builders.join_map("\n") { |hash| "#{hash[:name]} (#{hash[:uid]})" }
      )
    end
  end

  describe "#status_color" do
    it "is green" do
      territory_example.flag_stolen = false
      territory_example.last_paid_at = ::Time.current.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.status_color).to eq(ESM::Color::Toast::GREEN)
    end

    it "is yellow" do
      territory_example.flag_stolen = false
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 3).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.status_color).to eq(ESM::Color::Toast::YELLOW)
    end

    it "is red (Stolen)" do
      territory_example.flag_stolen = true

      expect(territory.status_color).to eq(ESM::Color::Toast::RED)
    end

    it "is red (Payment due)" do
      territory_example.flag_stolen = false
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 1).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.status_color).to eq(ESM::Color::Toast::RED)
    end
  end

  describe "#days_left_until_payment_due" do
    it "is expected to return the value (Just Paid)" do
      last_paid_at = ::Time.current
      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.days_left_until_payment_due).to eq(settings.territory_lifetime)
    end

    it "is expected to return the value (Needs payment)" do
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 3).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.days_left_until_payment_due).to eq(3)
    end

    it "is expected to return the value (Payment ASAP)" do
      last_paid_at = ::Time.zone.today - (settings.territory_lifetime - 1).days
      territory_example.last_paid_at = last_paid_at.to_time.strftime(TerritoryGenerator::TIME_FORMAT)

      expect(territory.days_left_until_payment_due).to eq(1)
    end
  end

  describe "#payment_reminder_message" do
    let(:time_left_message) do
      next_due_date = territory_example.last_paid_at + settings.territory_lifetime.days

      "You have `#{ESM::Time.distance_of_time_in_words(next_due_date, precise: false)}` until your next payment is due."
    end

    it "is expected to return a message (Just paid)" do
      last_paid_at = ::Time.current

      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)
      expect(territory.payment_reminder_message).to eq("")
    end

    it "is expected to return a message (Needing to pay)" do
      last_paid_at = ::Time.current - (settings.territory_lifetime - 3).days
      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)
      expect(territory.payment_reminder_message).to eq(":warning: **You should consider making a base payment soon.**\n#{time_left_message}")
    end

    it "is expected to return a message (pay ASAP)" do
      last_paid_at = ::Time.current - (settings.territory_lifetime - 1).days
      territory_example.last_paid_at = last_paid_at.strftime(TerritoryGenerator::TIME_FORMAT)
      expect(territory.payment_reminder_message).to eq(":alarm_clock: **You should make a base payment ASAP to avoid losing your base!**\n#{time_left_message}")
    end
  end

  describe "#convert_flag_path" do
    let(:base_path) { "https://exile-server-manager.s3.amazonaws.com/flags" }
    let(:default_flag) { "#{base_path}/flag_white_co.jpg" }

    it "parses arma path" do
      expect(territory.send(:convert_flag_path, "\\A3\\Data_F\\Flags\\flag_us_co.paa")).to eq("#{base_path}/flag_us_co.jpg")
    end

    it "parses exile mod path" do
      expect(territory.send(:convert_flag_path, "exile_assets\\texture\\flag\\flag_misc_knuckles_co.paa")).to eq("#{base_path}/flag_misc_knuckles_co.jpg")
    end

    it "is expected to return the value default" do
      expect(territory.send(:convert_flag_path, "")).to eq(default_flag)
      expect(territory.send(:convert_flag_path, "foo_bar_flag")).to eq(default_flag)
      expect(territory.send(:convert_flag_path, "\\A3\\SomeDirectory\\flag_something.paa")).to eq(default_flag)
    end
  end
end
