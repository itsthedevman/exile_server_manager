# frozen_string_literal: true

require_relative "../lib/esm"
require_relative "../spec/support/additions/esm/test"

# =============================================================================
# BOT INITIALIZATION
# =============================================================================

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

# =============================================================================
# COMMUNITIES
# =============================================================================

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
    guild_id: "901967248653189180",
    player_mode_enabled: true
  }
].map do |community_data|
  print "  Creating community for #{community_data[:community_id]}..."
  community = ESM::Community.create!(community_data)
  puts " done"
  community
end

community = communities.first
player_mode_community = communities.second
puts " done"

print "Unlocking all commands..."
ESM::CommandConfiguration.all.update!(allowed_in_text_channels: true, allowlist_enabled: false)
puts " done"

# =============================================================================
# SERVERS
# =============================================================================

print "Creating servers..."
server_1 = ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_malden",
  server_name: "Exile Server Manager",
  server_key: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d",
  server_ip: "127.0.0.1",
  server_port: "2602"
)

server_2 = ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_test",
  server_name: "Exile Server Manager (Test)",
  server_key: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb332658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d",
  server_ip: "127.0.0.1",
  server_port: "2302"
)
puts " done"

# =============================================================================
# SERVER MODS & REWARDS
# =============================================================================

print "Creating server mods..."
ESM::ServerMod.create!(
  server_id: server_1.id,
  mod_name: "Exile",
  mod_link: "https://www.exilemod.com",
  mod_version: "1.0.5",
  mod_required: true
)

ESM::ServerMod.create!(
  server_id: server_1.id,
  mod_name: "ADT",
  mod_link: "",
  mod_version: "1",
  mod_required: false
)
puts " done"

print "Creating server rewards..."
# Default reward
server_1.server_rewards.where(reward_id: nil).first.update!(
  server_id: server_1.id,
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

# Vehicle reward
server_1.server_rewards.create!(
  server_id: server_1.id,
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

# =============================================================================
# USERS
# =============================================================================

print "Creating users..."
users = [
  {discord_id: "137709767954137088", discord_username: "Bryan", steam_uid: nil},
  {discord_id: "477847544521687040", discord_username: "Bryan V2", steam_uid: "76561198037177305"},
  {discord_id: "683476391664156700", discord_username: "Bryan V3", steam_uid: ESM::Test.data[:steam_uids].sample}
].map do |user_info|
  user = ESM::User.create!(**user_info)
  ESM::UserNotificationPreference.create!(user_id: user.id, server_id: server_1.id)
  user
end

# Set defaults and aliases for main user
ESM::UserDefault.where(user_id: 1).update(server_id: server_1.id, community_id: community.id)
ESM::UserAlias.create!(user_id: 1, server_id: server_1.id, value: "s")
ESM::UserAlias.create!(user_id: 1, community_id: community.id, value: "c")
puts " done"

# =============================================================================
# NOTIFICATION ROUTES
# =============================================================================

# So we can access some test data
require ESM.root.join("spec/support/additions/esm/test.rb")

puts "Creating user notification routes..."
user = users.first
channels = ESM::Test.data.dig(:secondary, :channels)

# Accepted & active routes
print "  Creating accepted routes..."
routes_data = [
  # #general - Territory events from server 1
  {server: server_1, channel: channels[0], type: "base-raid", enabled: true},
  {server: server_1, channel: channels[0], type: "flag-stolen", enabled: true},
  {server: server_1, channel: channels[0], type: "flag-restored", enabled: false},

  # #notifications - Economy events from any server
  {server: nil, channel: channels[1], type: "protection-money-due", enabled: true},
  {server: nil, channel: channels[1], type: "marxet-item-sold", enabled: true},

  # #raid-alerts - Combat events from server 2
  {server: server_2, channel: channels[2], type: "hack-started", enabled: true},
  {server: server_2, channel: channels[2], type: "grind-started", enabled: true},
  {server: server_2, channel: channels[2], type: "charge-plant-started", enabled: false}
]

routes_data.each do |route_data|
  ESM::UserNotificationRoute.create!(
    user: user,
    source_server: route_data[:server],
    destination_community: player_mode_community,
    channel_id: route_data[:channel],
    notification_type: route_data[:type],
    enabled: route_data[:enabled],
    user_accepted: true,
    community_accepted: true
  )
end
puts " done"

# Pending routes
print "  Creating pending routes..."
# Pending community acceptance
ESM::UserNotificationRoute.create!(
  user: user,
  source_server: server_1,
  destination_community: player_mode_community,
  channel_id: channels[0],
  notification_type: "protection-money-paid",
  enabled: true,
  user_accepted: true,
  community_accepted: false
)

# Pending user acceptance
ESM::UserNotificationRoute.create!(
  user: user,
  source_server: server_2,
  destination_community: player_mode_community,
  channel_id: channels[2],
  notification_type: "flag-steal-started",
  enabled: true,
  user_accepted: false,
  community_accepted: true
)
puts " done"

# =============================================================================
# LOGS
# =============================================================================

print "Creating sample logs..."
log = ESM::Log.create!(
  public_id: SecureRandom.uuid,
  requestors_user_id: user.id,
  server: server_1,
  search_text: "robra",
  created_at: 2.hours.ago,
  expires_at: 15.days.from_now
)

# Trading log entries
ESM::LogEntry.create!(
  public_id: SecureRandom.uuid,
  log: log,
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

# More trading entries
ESM::LogEntry.create!(
  public_id: SecureRandom.uuid,
  log: log,
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
    }
  ]
)

# Death log entries
ESM::LogEntry.create!(
  public_id: SecureRandom.uuid,
  log: log,
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
    }
  ]
)
puts " done"

# =============================================================================
# FINALIZATION
# =============================================================================

Redis.new.set("server_key", server_1.token.to_json)

puts ""
puts "Seeds completed successfully!"
puts "Communities: #{ESM::Community.count}"
puts "Servers: #{ESM::Server.count}"
puts "Users: #{ESM::User.count}"
puts "Notification Routes: #{ESM::UserNotificationRoute.count} (#{ESM::UserNotificationRoute.accepted.count} accepted)"
puts ""
