# frozen_string_literal: true

require_relative "../lib/esm"
require_relative "../spec/support/additions/esm/test"

puts "Waiting for ESM to start..."
ESM.run!(async: true)

until ESM.bot.ready?
  sleep 1
end
puts " done"

print "Checking commands for invalid configurations..."
ESM::Command.all.each(&:check_for_valid_configuration!)
puts " done"

print "Configuring bot..."
ESM::BotAttribute.create!(
  maintenance_mode_enabled: false,
  maintenance_message: "",
  status_type: "PLAYING",
  status_message: "Extension V2 development"
)
puts " done"

puts "Creating communities..."
communities = [
  {
    community_id: "esm",
    community_name: "ESM Test Server 1",
    guild_id: "452568470765305866",
    logging_channel_id: "901965726305382400",
    player_mode_enabled: false
  },
  {
    community_id: "esm2",
    community_name: "ESM Test Server 2",
    guild_id: "901967248653189180"
  }
  # {
  #   community_id: "zdt",
  #   community_name: "ZDT",
  #   guild_id: "421111581267591168",
  #   player_mode_enabled: false
  # }
].map do |community|
  print "  Creating community for #{community[:community_id]}..."
  community = ESM::Community.create!(community)
  puts " done"

  community
end

community = communities.first
puts " done"

print "Unlocking all commands"
ESM::CommandConfiguration.all.update!(allowed_in_text_channels: true, allowlist_enabled: false)
puts " done"

print "Creating servers..."
server = ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_malden",
  server_name: "Exile Server Manager",
  server_key: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d",
  server_ip: "127.0.0.1",
  server_port: "2602"
)

ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_test",
  server_name: "Exile Server Manager (Test)",
  server_key: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb332658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d",
  server_ip: "127.0.0.1",
  server_port: "2302"
)

ESM::ServerMod.create!(
  server_id: server.id,
  mod_name: "Exile",
  mod_link: "https://www.exilemod.com",
  mod_version: "1.0.5",
  mod_required: true
)

ESM::ServerMod.create!(
  server_id: server.id,
  mod_name: "ADT",
  mod_link: "",
  mod_version: "1",
  mod_required: false
)

# This is the default reward
server.server_rewards.where(reward_id: nil).first.update!(
  server_id: server.id,
  reward_id: nil,
  reward_items: {
    Exile_Item_WoodDoorKit: 1,
    Exile_Item_WoodWallKit: 3,
    Exile_Item_WoodFloorKit: 2
  },
  reward_vehicles: [],
  player_poptabs: 12_345,
  locker_poptabs: 98_765,
  respect: 1
)

server.server_rewards.create!(
  server_id: server.id,
  reward_id: "vehicles",
  reward_items: {},
  reward_vehicles: [
    {
      class_name: "Exile_Car_Hatchback_Beige",
      spawn_location: "nearby"
    },
    {
      class_name: "Exile_Chopper_Huron_Black",
      spawn_location: "virtual_garage"
    },
    {
      class_name: "Exile_Car_Hunter",
      spawn_location: "player_decides"
    }
  ],
  player_poptabs: 0,
  locker_poptabs: 0,
  respect: 0
)
puts " done"

print "Creating users..."
[
  {discord_id: "137709767954137088", discord_username: "Bryan", steam_uid: nil},
  {discord_id: "477847544521687040", discord_username: "Bryan V2", steam_uid: "76561198037177305"},
  {discord_id: "683476391664156700", discord_username: "Bryan V3", steam_uid: ESM::Test.data[:steam_uids].sample}
].each do |user_info|
  user = ESM::User.create!(**user_info)
  ESM::UserNotificationPreference.create!(user_id: user.id, server_id: server.id)
end

ESM::UserDefault.where(user_id: 1).update(server_id: server.id, community_id: community.id)
ESM::UserAlias.create!(user_id: 1, server_id: server.id, value: "s")
ESM::UserAlias.create!(user_id: 1, community_id: community.id, value: "c")
puts " done"

Redis.new.set("server_key", server.token.to_json)

puts "Creating logs..."

log = ESM::Log.create!(
  public_id: SecureRandom.uuid,
  requestors_user_id: ESM::User.all.pluck(:id).sample,
  server:,
  search_text: "robra",
  created_at: 2.hours.ago,
  expires_at: 15.days.from_now
)

# Create log entries
ESM::LogEntry.create!(
  public_id: SecureRandom.uuid,
  log:,
  file_name: "Exile_TradingLog.log",
  entries: [
    {
      timestamp: "2025-02-15T19:03:39.000-05:00",
      line_number: 1234,
      entry: "PLAYER: ( 76561199032144610 ) R NSTR:2 (robra) REMOTE PURCHASED ITEM MiniGrenade FOR 125 POPTABS | PLAYER TOTAL MONEY: 24874"
    },
    {
      timestamp: "2025-02-15T19:05:22.000-05:00",
      line_number: 1236,
      entry: "PLAYER: ( 76561199032144610 ) R NSTR:2 (robra) REMOTE SOLD ITEM Land_Trophy_01_gold_F_Kit FOR 250000 POPTABS AND 125000 RESPECT | PLAYER TOTAL MONEY: 274874"
    },
    {
      timestamp: "2025-02-15T20:29:52.000-05:00",
      line_number: 1244,
      entry: "PLAYER: ( 76561199032144610 ) R NSTR:5 (robra) REMOTE PURCHASED VEHICLE CUP_B_JAS39_HIL FOR 1.2e+06 POPTABS | PLAYER TOTAL MONEY: 55000"
    }
  ]
)

# Second day with timestamped entries
ESM::LogEntry.create!(
  public_id: SecureRandom.uuid,
  log:,
  file_name: "Exile_TradingLog.log",
  entries: [
    {
      timestamp: "2025-02-16T09:13:32.000-05:00",
      line_number: 567,
      entry: "[04:13:32:252334 --5:00] [Thread 94108] PLAYER: ( 76561199032144610 ) R NSTR:2 (robra) REMOTE SOLD ITEM Exile_Item_PlasticBottleEmpty FOR 10 POPTABS AND 1 RESPECT | PLAYER TOTAL MONEY: 24214"
    },
    {
      timestamp: "2025-02-16T09:12:46.000-05:00",
      line_number: 565,
      entry: "[04:12:46:912447 --5:00] [Thread 92200] PLAYER: ( 76561199032144610 ) R NSTR:2 (robra) REMOTE PURCHASED ITEM hlc_20Rnd_762x51_B_M14 FOR 200 POPTABS | PLAYER TOTAL MONEY: 24374"
    },
    {
      timestamp: "2025-02-16T07:55:06.000-05:00",
      line_number: 523,
      entry: "[02:55:06:071228 --5:00] [Thread 91468] PLAYER: ( 76561199032144610 ) R NSTR:5 (robra) REMOTE SOLD ITEM: CUP_B_M6LineBacker_USA_W (ID# 18429) with Cargo [\"100Rnd_65x39_caseless_mag_Tracer\",\"arifle_ARX_hex_F\"] FOR 376015 POPTABS AND 37601.5 RESPECT | PLAYER TOTAL MONEY: 377015"
    }
  ]
)

# Third day with death messages
ESM::LogEntry.create!(
  public_id: SecureRandom.uuid,
  log:,
  file_name: "Exile_DeathLog.log",
  entries: [
    {
      timestamp: "2025-02-17T14:23:12.000-05:00",
      line_number: 892,
      entry: "robra died because robra was very unlucky."
    },
    {
      timestamp: "2025-02-17T15:45:33.000-05:00",
      line_number: 934,
      entry: "robra died due to Arma bugs and is probably very salty right now."
    },
    {
      timestamp: "2025-02-17T16:12:44.000-05:00",
      line_number: 967,
      entry: "robra died a mysterious death."
    },
    {
      timestamp: "2025-02-17T17:33:21.000-05:00",
      line_number: 998,
      entry: "robra died because... Arma."
    }
  ]
)

puts " done"
