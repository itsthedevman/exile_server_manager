# frozen_string_literal: true

describe ESM::Event::ServerInitializationV1 do
  # This has to be esm_community for roles
  let!(:community) { create(:esm_community, territory_admin_ids: ["440254072780488714", "440296219726708747"]) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }
  let(:reward) { server.server_reward }
  let(:setting) { server.server_setting }
  let!(:packet) do
    OpenStruct.new(
      server_name: Faker::Commerce.product_name,
      price_per_object: 150,
      territory_lifetime: 7,
      server_restart: [3, 30],
      server_start_time: DateTime.now.strftime("%Y-%m-%dT%H:%M:%S"),
      server_version: "2.0.0",
      territory_level_1: {level: 1, purchase_price: 5000, radius: 15, object_count: 30},
      territory_level_2: {level: 2, purchase_price: 10_000, radius: 30, object_count: 60},
      territory_level_3: {level: 3, purchase_price: 15_000, radius: 45, object_count: 90},
      territory_level_4: {level: 4, purchase_price: 20_000, radius: 60, object_count: 120},
      territory_level_5: {level: 5, purchase_price: 25_000, radius: 75, object_count: 150},
      territory_level_6: {level: 6, purchase_price: 30_000, radius: 90, object_count: 180},
      territory_level_7: {level: 7, purchase_price: 35_000, radius: 105, object_count: 210},
      territory_level_8: {level: 8, purchase_price: 40_000, radius: 120, object_count: 240},
      territory_level_9: {level: 9, purchase_price: 45_000, radius: 135, object_count: 270},
      territory_level_10: {level: 10, purchase_price: 50_000, radius: 150, object_count: 300}
    )
  end

  describe "#run!" do
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:event) { ESM::Event::ServerInitializationV1.new(server: server, parameters: packet, connection: connection) }

    before do
      wait_for { wsc.connected? }.to eq(true)
      expect { event.run! }.not_to raise_error
    end

    after do
      wsc.disconnect!
    end

    it "should valid" do
      expect(event).not_to be_nil
    end

    describe "#initialize_server!" do
      before do
        server.reload
      end

      it "should have updated the server" do
        expect(server.server_name).to eq(packet.server_name)
        expect(server.server_start_time).to eq(DateTime.parse(packet.server_start_time).utc)
      end

      it "should have updated the server settings" do
        settings = server.server_setting

        expect(settings.territory_price_per_object).to eq(packet.price_per_object)
        expect(settings.territory_lifetime).to eq(packet.territory_lifetime)
        expect(settings.server_restart_hour).to eq(packet.server_restart.first)
        expect(settings.server_restart_min).to eq(packet.server_restart.second)
      end

      it "should have created territories" do
        expect(ESM::Territory.where(server_id: server.id).size).to eq(10)

        packet_territories = packet.to_h.select { |key, _| key.to_s.starts_with?("territory_level_") }

        packet_territories.each do |_, info|
          territory = ESM::Territory.where(server_id: server.id, territory_level: info[:level]).first
          expect(territory).not_to be_nil
          expect(territory.territory_level).to eq(info[:level])
          expect(territory.territory_purchase_price).to eq(info[:purchase_price])
          expect(territory.territory_radius).to eq(info[:radius])
          expect(territory.territory_object_count).to eq(info[:object_count])
        end
      end
    end

    describe "#build_settings_packet" do
      before do
        server.reload
        setting.reload
        reward.reload
      end

      it "should be valid" do
        member = user.discord_user.on(community.discord_server)
        expect(event.packet.territory_admins).to eq("[\"#{user.steam_uid}\"]") if member && (member.owner? || community.territory_admin_ids.any? { |id| member.role?(id) })

        expect(event.packet.function_name).to eq("postServerInitialization")
        expect(event.packet.server_id).to eq(server.server_id)
        expect(event.packet.extdb_path).to eq(setting.extdb_path || "")
        expect(event.packet.gambling_modifier).to eq(setting.gambling_modifier)
        expect(event.packet.gambling_payout).to eq(setting.gambling_payout_base)
        expect(event.packet.gambling_randomizer_max).to eq(setting.gambling_payout_randomizer_max)
        expect(event.packet.gambling_randomizer_mid).to eq(setting.gambling_payout_randomizer_mid)
        expect(event.packet.gambling_randomizer_min).to eq(setting.gambling_payout_randomizer_min)
        expect(event.packet.gambling_win_chance).to eq(setting.gambling_win_percentage)
        expect(event.packet.logging_add_player_to_territory).to eq(setting.logging_add_player_to_territory)
        expect(event.packet.logging_demote_player).to eq(setting.logging_demote_player)
        expect(event.packet.logging_exec).to eq(setting.logging_exec)
        expect(event.packet.logging_gamble).to eq(setting.logging_gamble)
        expect(event.packet.logging_modify_player).to eq(setting.logging_modify_player)
        expect(event.packet.logging_pay_territory).to eq(setting.logging_pay_territory)
        expect(event.packet.logging_promote_player).to eq(setting.logging_promote_player)
        expect(event.packet.logging_remove_player_from_territory).to eq(setting.logging_remove_player_from_territory)
        expect(event.packet.logging_reward).to eq(setting.logging_reward_player)
        expect(event.packet.logging_transfer).to eq(setting.logging_transfer_poptabs)
        expect(event.packet.logging_upgrade_territory).to eq(setting.logging_upgrade_territory)
        expect(event.packet.logging_path).to eq(setting.logging_path || "")
        expect(event.packet.max_payment_count).to eq(setting.max_payment_count)
        expect(event.packet.request_thread_tick).to eq(setting.request_thread_tick)
        expect(event.packet.request_thread_type).to eq(setting.request_thread_type == "exile")
        expect(event.packet.taxes_territory_payment).to eq(setting.territory_payment_tax / 100)
        expect(event.packet.taxes_territory_upgrade).to eq(setting.territory_upgrade_tax / 100)
        expect(event.packet.reward_player_poptabs).to eq(reward.player_poptabs)
        expect(event.packet.reward_locker_poptabs).to eq(reward.locker_poptabs)
        expect(event.packet.reward_respect).to eq(reward.respect)
        expect(event.packet.reward_items).to eq(reward.reward_items.to_a.to_json)
      end
    end
  end
end
