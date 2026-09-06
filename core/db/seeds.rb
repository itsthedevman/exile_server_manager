# frozen_string_literal: true

# seeds.rb runs against the bot's bootable ESM (it needs ESM.run!,
# Discord delivery, command loader, etc.); core's slim ESM module on its own
# doesn't have those. Pull in service's full boot from the env-var path.
require Pathname.new(ENV.fetch("ESM_SERVICE_PATH")).join("lib", "esm.rb")

# Mock fixture values that used to come from spec_data.yml (`ESM::Test.data`).
# That file held real (anonymized) Steam UIDs and a private Discord guild's
# channel IDs; the Discord-mock spec rewrite retired it. These placeholders
# are dev-only and intentionally don't resolve to real Steam accounts or
# Discord channels.
mock_steam_uids = Array.new(5) { "7656119#{rand(10**10).to_s.rjust(10, "0")}" }.freeze
mock_secondary_channels = %w[
  900000000000000001
  900000000000000002
  900000000000000003
].freeze

# =============================================================================
# BOT INITIALIZATION
# =============================================================================

puts "Starting ESM..."
ESM.run!(async: true, bare: true)
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
# USERS
# =============================================================================

print "Creating users..."
users = [
  {discord_id: "137709767954137088", discord_username: "Bryan", steam_uid: "76561198037177305"},
  {
    discord_id: "477847544521687040",
    discord_username: "Bryan V2",
    steam_uid: mock_steam_uids.sample
  },
  {
    discord_id: "683476391664156700",
    discord_username: "Bryan V3",
    steam_uid: mock_steam_uids.sample
  }
].map do |user_info|
  ESM::User.create!(**user_info)
end

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
    player_mode_enabled: false,
    owner_user_id: users.first.id
  },
  {
    community_id: "esm2",
    community_name: "ESM Test Server 2",
    guild_id: "901967248653189180",
    player_mode_enabled: true,
    owner_user_id: users.first.id
  },
  {
    community_id: "esm3",
    community_name: "ESM Test Server 3",
    guild_id: "1203080566417784842",
    player_mode_enabled: false,
    owner_user_id: users.second.id
  }
].map do |community_data|
  print "  Creating community for #{community_data[:community_id]}..."
  community = ESM::Community.create!(community_data)
  puts " done"
  community
end

community = communities.first
player_mode_community = communities.second
other_community = communities.third
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
  server_port: "2302",
  ui_version: "2.0.0"
)

server_2 = ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_test",
  server_name: "Exile Server Manager (Test)",
  server_key: "caTkTRCt25iwaG7RJxN99aDtbib4gAtsylETLDpubgCuA86TFVqIFeRWLkQIHA1hqNwRrBpEtAVdEK7RtgCdNnfxkT8Hbj3y0TqaRrfpRffJ6Znndae3qfYRXSDxHWteLQLDRH0rjiIJfWMAxeK4G9QUmWkxnxEvguKuwLHfQxpAS3gEmykw3MkAhbosSqU6HNMxqNQESgpx9ddS8CPrSC2FOcSMP8GkBQ3PrzlbSLNYYzqv",
  server_ip: "127.0.0.1",
  server_port: "2602"
)

ESM::Server.create!(
  community_id: other_community.id,
  server_id: "esm3_never_connected",
  server_name: "Exile Server Manager (Never connected)",
  server_key: "dM34fkvl7FIcL63HGquV8ANXYWyXZs1epBvNDm0E30SnkvibqpwvhgtVHKlI8XMr9uUhhNXsR2kkkqRj19q5QfcCWsJv5AiChU7KsFdaXb4ommnADOVIWXa8kBzckadUrpQ1Yjdf0VzlIpazF3823DQBEBhMdFj7Ym5y8vERioyUuMV8KJo6h0OmTsXDc20Ndhi6oDnMOxN4YHrIHepcpAQIFFBoP9l7Myi3vt03IW9WBwnG",
  server_ip: "127.0.0.1",
  server_port: "2902"
)

ESM::Server.create!(
  community_id: other_community.id,
  server_id: "esm3_offline",
  server_name: "Exile Server Manager (Offline)",
  server_key: "RazAmngvDJd7gIn0E1LRJ5BDSISrmVT2FqxylXYO4eqgRqtuJTl4zDeClZws05Pq8Ej0OxC09LomYPrtfNN2cWu52IDv1QNvliJKibfSVbGuGJlW0juQ251jr4cqLJtbotM6Rgh5QrQLz2lA0fWw10uwKlOcF8hDcCzVOjHLTOMvCs8DvZJRs8u7K5RGb3duK9aZgeeqUJBwwiUTbD9U7J9aStryaLLJOVgd94knAq3Bvpgq",
  server_ip: "127.0.0.1",
  server_port: "2902",
  server_version: "2.0.0"
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
server_1.server_rewards.default.first.update!(
  name: "Welcome package",
  reward_items: {
    Exile_Item_WoodDoorKit: 1,
    Exile_Item_WoodWallKit: 3,
    Exile_Item_WoodFloorKit: 2
  },
  reward_vehicles: [
    {
      class_name: "Exile_Car_Hatchback_Beige",
      spawn_location: "nearby"
    }
  ],
  player_poptabs: 12_345,
  locker_poptabs: 98_765,
  respect: 1
)

# Vehicle reward
server_1.server_rewards.create!(
  name: "Awesome Vehicles",
  reward_id: "vehicles",
  reward_items: {
    Exile_Item_JunkMetal: 2
  },
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

server_1.server_rewards.create!(
  name: "Get Rich Quick",
  reward_id: "getrichquick",
  reward_items: {},
  reward_vehicles: [],
  player_poptabs: 15_000,
  locker_poptabs: 100_000,
  respect: 0
)
puts " done"

# =============================================================================
# USERS EXTRA
# =============================================================================

users.each do |user|
  ESM::UserNotificationPreference.create!(user_id: user.id, server_id: server_1.id)
end

# Set defaults and aliases for main user
ESM::UserDefault.where(user_id: users.first.id).update(server_id: server_1.id, community_id: community.id)
ESM::UserAlias.create!(user_id: users.first.id, server_id: server_1.id, value: "s")
ESM::UserAlias.create!(user_id: users.first.id, community_id: community.id, value: "c")

ESM::UserServerFavorite.create!(user_id: users.first.id, server_id: server_1.id)
ESM::UserServerFavorite.create!(user_id: users.first.id, server_id: server_2.id)

# =============================================================================
# GAMBLE STATS
# =============================================================================

print "Creating gamble stats..."
# server_1 gets a full leaderboard spread: V2 owns the streaks and most-won,
# V3 owns the losses, and the main user sits mid-pack. server_2 gets just the
# main user, so switching servers shows a different (sparser) card.
gamble_stats = [
  {
    user: users.first, server: server_1, current_streak: 4, last_action: "loss",
    total_wins: 128, total_losses: 141, longest_win_streak: 9, longest_loss_streak: 7,
    total_poptabs_won: 4_820_000, total_poptabs_loss: 5_130_000
  },
  {
    user: users.second, server: server_1, current_streak: 11, last_action: "won",
    total_wins: 340, total_losses: 210, longest_win_streak: 15, longest_loss_streak: 5,
    total_poptabs_won: 12_500_000, total_poptabs_loss: 3_200_000
  },
  {
    user: users.third, server: server_1, current_streak: 2, last_action: "loss",
    total_wins: 88, total_losses: 260, longest_win_streak: 6, longest_loss_streak: 18,
    total_poptabs_won: 2_100_000, total_poptabs_loss: 9_800_000
  },
  {
    user: users.first, server: server_2, current_streak: 3, last_action: "won",
    total_wins: 22, total_losses: 15, longest_win_streak: 5, longest_loss_streak: 3,
    total_poptabs_won: 640_000, total_poptabs_loss: 410_000
  }
]

gamble_stats.each do |stat_data|
  gambler = stat_data.delete(:user)
  gamble_server = stat_data.delete(:server)
  ESM::UserGambleStat.create!(user_id: gambler.id, server_id: gamble_server.id, **stat_data)
end
puts " done"

# =============================================================================
# COOLDOWNS
# =============================================================================

print "Creating cooldowns..."
# Everything the cooldowns page has to be able to draw: both cooldown types, both ways a row is keyed to its owner, a
# row with no server, and rows that have to stay out of the running list. The configurations go first, because
# changing one reconciles the community's existing rows to match it and would rewrite these on the way past.
community.command_configurations
  .where(command_name: "reward")
  .update(cooldown_type: "times", cooldown_quantity: 2)

community.command_configurations
  .where(command_name: "gamble")
  .update(cooldown_type: "hours", cooldown_quantity: 6)

cooldowns = [
  # The case the page exists for: an allowance spent, on the command communities actually put a limit on.
  {
    command_name: "reward", steam_uid: users.first.steam_uid, server: server_1,
    cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 2
  },

  # The same allowance, half used. Not running, so it only appears once finished rows are asked for.
  {
    command_name: "reward", steam_uid: users.second.steam_uid, server: server_1,
    cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 1
  },

  # Clocks at two distances from expiring, both far enough out to still be running whenever the seeds are next
  # looked at. Minutes read nicely in the table and are gone before anyone opens the page.
  {
    command_name: "gamble", steam_uid: users.second.steam_uid, server: server_1,
    cooldown_type: "hours", cooldown_quantity: 6, expires_at: 4.hours.from_now
  },
  {
    command_name: "gamble", steam_uid: users.third.steam_uid, server: server_1,
    cooldown_type: "hours", cooldown_quantity: 6, expires_at: 70.minutes.from_now
  },

  # A second server, so the server filter has something to separate.
  {
    command_name: "reward", steam_uid: users.third.steam_uid, server: server_2,
    cooldown_type: "times", cooldown_quantity: 2, cooldown_amount: 2
  },

  # Keyed by user_id rather than steam_uid, which is how a command that needs no registration stores its cooldown.
  {
    command_name: "id", user_id: users.first.id, server: nil,
    cooldown_type: "days", cooldown_quantity: 2, expires_at: 2.days.from_now
  },

  # No server at all, the shape every community-scoped command's cooldown takes. Deliberately not reset_cooldown:
  # running that leaves a row of its own, and seeding a long one alongside makes the page look like clearing
  # cooldowns blocks you from clearing again, when the real throttle is a couple of seconds.
  {
    command_name: "whois", steam_uid: users.first.steam_uid, server: nil,
    cooldown_type: "hours", cooldown_quantity: 12, expires_at: 8.hours.from_now
  },

  # Long run out. Only appears under "Include finished".
  {
    command_name: "me", steam_uid: users.first.steam_uid, server: server_1,
    cooldown_type: "minutes", cooldown_quantity: 5, expires_at: 2.hours.ago
  }
]

cooldowns.each do |cooldown_data|
  cooldown_server = cooldown_data.delete(:server)

  ESM::Cooldown.create!(community_id: community.id, server_id: cooldown_server&.id, **cooldown_data)
end

# Belongs to somebody else. Nothing on this community's page should ever reach it.
ESM::Cooldown.create!(
  community_id: other_community.id,
  server_id: nil,
  command_name: "reward",
  steam_uid: users.first.steam_uid,
  cooldown_type: "times",
  cooldown_quantity: 2,
  cooldown_amount: 2
)
puts " done"

# =============================================================================
# NOTIFICATION ROUTES
# =============================================================================

puts "Creating user notification routes..."
user, user2, user3 = users
channels = mock_secondary_channels

# Accepted & active routes
print "  Creating accepted routes for user..."
accepted_routes_data = [
  {server: server_1, channel: channels.first, type: "base-raid", enabled: true},
  {server: server_1, channel: channels.first, type: "flag-stolen", enabled: true},
  {server: nil, channel: channels.second, type: "protection-money-due", enabled: true},
  {server: nil, channel: channels.second, type: "marxet-item-sold", enabled: false}
]

accepted_routes_data.each do |route_data|
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

ESM::UserNotificationRoute::TYPES.each do |type|
  ESM::UserNotificationRoute.create!(
    user: user,
    source_server: server_2,
    destination_community: player_mode_community,
    channel_id: channels.third,
    notification_type: type,
    user_accepted: true,
    community_accepted: false
  )
end

ESM::UserNotificationRoute::TYPES.each do |type|
  ESM::UserNotificationRoute.create!(
    user: user2,
    source_server: server_1,
    destination_community: player_mode_community,
    channel_id: channels.first,
    notification_type: type,
    user_accepted: true,
    community_accepted: false
  )
end

ESM::UserNotificationRoute::TYPES.each do |type|
  ESM::UserNotificationRoute.create!(
    user: user3,
    source_server: server_2,
    destination_community: player_mode_community,
    channel_id: channels.second,
    notification_type: type,
    user_accepted: true,
    community_accepted: false
  )
end

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

redis = Redis.new
ESM::Server.all.each { |server| redis.set("server_key:#{server.server_id}", server.token.to_json) }
redis.set("server_key", server_1.token.to_json)

puts ""
puts "Seeds completed successfully!"
puts "Communities: #{ESM::Community.count}"
puts "Servers: #{ESM::Server.count}"
puts "Users: #{ESM::User.count}"
puts "Notification Routes: #{ESM::UserNotificationRoute.count} (#{ESM::UserNotificationRoute.accepted.count} accepted)"
puts ""
