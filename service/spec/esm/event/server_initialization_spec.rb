# frozen_string_literal: true

describe ESM::Event::ServerInitialization, :requires_connection, v2: true do
  include_context "connection"

  let(:discord_server) { build(:discord_server, channels: [:logging], roles: %i[territory_admin]) }
  let(:territory_admin_role) { discord_server.roles.find { |r| r.name == "territory_admin" } }
  let(:user) do
    user_record = create(
      :user,
      :with_discord_member,
      discord_server: discord_server,
      discord_member_roles: [territory_admin_role]
    )
    user_record.role_id = territory_admin_role.id
    user_record
  end
  let(:setting) { server.server_setting }
  let(:reward) { server.server_reward }

  let!(:message) do
    ESM::Message.new
      .set_type(:init)
      .set_data(
        extension_version: "2.0.0",
        server_name: server.server_name,
        price_per_object: Faker::Number.between(from: 0, to: 1_000_000_000),
        territory_lifetime: Faker::Number.between(from: 0, to: 1_000),
        territory_data: [
          [["level", 1], ["purchase_price", 5000], ["radius", 15], ["object_count", 30]],
          [["level", 2], ["purchase_price", 10_000], ["radius", 30], ["object_count", 60]],
          [["level", 3], ["purchase_price", 15_000], ["radius", 45], ["object_count", 90]],
          [["level", 4], ["purchase_price", 20_000], ["radius", 60], ["object_count", 120]],
          [["level", 5], ["purchase_price", 25_000], ["radius", 75], ["object_count", 150]],
          [["level", 6], ["purchase_price", 30_000], ["radius", 90], ["object_count", 180]],
          [["level", 7], ["purchase_price", 35_000], ["radius", 105], ["object_count", 210]],
          [["level", 8], ["purchase_price", 40_000], ["radius", 120], ["object_count", 240]],
          [["level", 9], ["purchase_price", 45_000], ["radius", 135], ["object_count", 270]],
          [["level", 10], ["purchase_price", 50_000], ["radius", 150], ["object_count", 300]]
        ].to_json,
        server_start_time: Time.now.utc.to_s,
        vg_enabled: true,
        vg_max_sizes: "[\"-1\",\"5\",\"8\",\"11\",\"13\",\"15\",\"18\",\"21\",\"25\",\"28\"]"
      )
  end

  let(:event) { described_class.new(server.connection, server, message) }

  before do
    # The server will auto connect and the code we're testing will initialize the server again
    allow_any_instance_of(ESM::Arma::Client).to receive(:send_message)

    # Update the data stored in the connection object, NOT the one in the test.
    server.community.update!(territory_admin_ids: [user.role_id.to_s])
    server.server_setting.update!(extdb_path: Faker::File.dir, logging_path: Faker::File.dir)
    server.reload
  end

  subject!(:run_event) { event.run! }

  it "updates the server" do
    expect(server.server_name).to eq(message.data.server_name)
    expect(server.server_start_time).to eq(message.data.server_start_time)
  end

  it "updates the server settings" do
    expect(setting.territory_price_per_object).to eq(message.data.price_per_object)
    expect(setting.territory_lifetime).to eq(message.data.territory_lifetime)
  end

  it "creates territories" do
    expect(ESM::Territory.where(server_id: server.id).size).to eq(10)

    data = message.data.territory_data.parse_json.map { |t| t.to_arma_hashmap.to_datum }
    data.each do |territory_data|
      territory = ESM::Territory.where(server_id: server.id, territory_level: territory_data.level).first
      expect(territory).not_to be_nil
      expect(territory.territory_level).to eq(territory_data.level)
      expect(territory.territory_purchase_price).to eq(territory_data.purchase_price)
      expect(territory.territory_radius).to eq(territory_data.radius)
      expect(territory.territory_object_count).to eq(territory_data.object_count)
    end
  end

  it "sends exactly the expected keys" do
    # build_setting_data is a strict allowlist now, so a missing or stray key is
    # a real bug (the extension reads these by name). Fail loudly on any drift.
    expect(event.data.keys).to match_array(
      %i[
        community_id function_name
        gambling_locker_limit_enabled gambling_modifier gambling_payout_base
        gambling_payout_randomizer_max gambling_payout_randomizer_mid
        gambling_payout_randomizer_min gambling_win_percentage
        logging_channel_id
        logging_command_add logging_command_demote logging_command_gamble
        logging_command_pay logging_command_player logging_command_promote
        logging_command_remove logging_command_reward logging_command_sqf
        logging_command_transfer logging_command_upgrade
        max_payment_count server_id
        taxes_territory_payment taxes_territory_upgrade territory_admin_uids
      ]
    )
  end

  it "settings data is valid" do
    data = event.data.to_datum

    if user.steam_uid.present?
      expect(data.territory_admin_uids).to eq([user.steam_uid])
    else
      expect(data.territory_admin_uids).to eq([])
    end

    expect(data.gambling_locker_limit_enabled).to eq(setting.gambling_locker_limit_enabled)
    expect(data.gambling_modifier).to eq(setting.gambling_modifier)
    expect(data.gambling_payout_base).to eq(setting.gambling_payout_base)
    expect(data.gambling_payout_randomizer_max).to eq(setting.gambling_payout_randomizer_max)
    expect(data.gambling_payout_randomizer_mid).to eq(setting.gambling_payout_randomizer_mid)
    expect(data.gambling_payout_randomizer_min).to eq(setting.gambling_payout_randomizer_min)
    expect(data.gambling_win_percentage).to eq(setting.gambling_win_percentage)

    # logging_command_* are the v2 renames of the v1 logging_* setting columns
    expect(data.logging_command_add).to eq(setting.logging_add_player_to_territory)
    expect(data.logging_command_demote).to eq(setting.logging_demote_player)
    expect(data.logging_command_gamble).to eq(setting.logging_gamble)
    expect(data.logging_command_pay).to eq(setting.logging_pay_territory)
    expect(data.logging_command_player).to eq(setting.logging_modify_player)
    expect(data.logging_command_promote).to eq(setting.logging_promote_player)
    expect(data.logging_command_remove).to eq(setting.logging_remove_player_from_territory)
    expect(data.logging_command_reward).to eq(setting.logging_reward_player)
    expect(data.logging_command_sqf).to eq(setting.logging_exec)
    expect(data.logging_command_transfer).to eq(setting.logging_transfer_poptabs)
    expect(data.logging_command_upgrade).to eq(setting.logging_upgrade_territory)

    expect(data.max_payment_count).to eq(setting.max_payment_count)
    expect(data.taxes_territory_payment).to eq(setting.territory_payment_tax / 100)
    expect(data.taxes_territory_upgrade).to eq(setting.territory_upgrade_tax / 100)
  end
end
