# frozen_string_literal: true

require "esm"

ESM.console!
ESM.run!

# I don't feel like breaking the bot to fix the seeds file.
# Just wait a couple of seconds for the DB to connect
sleep 2

ESM::BotAttribute.create!(
  maintenance_mode_enabled: false,
  maintenance_message: "",
  status_type: "PLAYING",
  status_message: "!register"
)

user = ESM::User.create!(
  discord_id: "137709767954137088",
  discord_username: "Bryan",
  discord_discriminator: "9876",
  steam_uid: "76561198037177305",
  steam_username: "Wolfkillarcadia"
)

community = ESM::Community.create!(
  community_id: "esm",
  community_name: "Exile Server Manager",
  community_website: "https://www.esmbot.com",
  guild_id: ESM::Community::ESM::ID,
  logging_channel_id: "624387002443497489",
  command_prefix: "~",
  player_mode_enabled: false
)

ESM::Community.create!(
  community_id: "test",
  community_name: "Bryan's Test Server",
  community_website: "https://www.esmbot.com",
  guild_id: ESM::Community::Secondary::ID,
  command_prefix: "pls "
)

ESM::Community.create!(
  community_id: "zdt",
  community_name: "ZDT",
  community_website: "https://www.zdt.com",
  guild_id: "421111581267591168"
)

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

ESM::UserNotificationPreference.create!(user_id: user.id, server_id: server.id)
