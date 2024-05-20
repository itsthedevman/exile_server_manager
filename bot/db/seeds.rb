# frozen_string_literal: true

# rubocop:disable Rails/Output

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

print "Deleting all global commands..."
::ESM.bot.get_application_commands.each(&:delete)
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

  print "  Deleting commands for #{community.community_id}..."
  ::ESM.bot.get_application_commands(server_id: community.guild_id).each(&:delete)
  puts " done"

  print "  Registering commands for #{community.community_id}..."
  ESM::Command.register_commands(community.guild_id)
  puts " done"

  community
end

community = communities.first
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
  {discord_id: "137709767954137088", discord_username: "Bryan", steam_uid: "76561198037177305"},
  {discord_id: "477847544521687040", discord_username: "Bryan V2", steam_uid: ESM::Test.data[:steam_uids].sample},
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

# rubocop:enable Rails/Output
