# frozen_string_literal: true

module ESM
  module Regex
    COMMUNITY_ID_OPTIONAL = /[^\s]*/i.freeze
    COMMUNITY_ID = /[^\s]+/i.freeze
    DISCORD_TAG = /<@[&!]?\d+>/.freeze
    DISCORD_TAG_ONLY = /^#{DISCORD_TAG.source}$/.freeze
    DISCORD_ID = /\d{18}/.freeze
    DISCORD_ID_ONLY = /^#{DISCORD_ID.source}$/.freeze
    STEAM_UID = /\d{17}/.freeze
    STEAM_UID_ONLY = /^#{STEAM_UID.source}$/.freeze
    TARGET = /#{DISCORD_TAG.source}|#{DISCORD_ID.source}|#{STEAM_UID.source}/.freeze
    SERVER_ID_OPTIONAL_COMMUNITY = /(?:[^\s]+_)*[^\s]+/.freeze
    SERVER_ID = /[^\s]+_[^\s]+/.freeze
    SERVER_ID_ONLY = /^#{SERVER_ID.source}$/.freeze
    TERRITORY_ID = /\w+/.freeze
    TERRITORY_ID_ONLY = /^#{TERRITORY_ID.source}$/.freeze
    FLAG_NAME = /(flag_.*)\.paa/.freeze
    BROADCAST = /#{SERVER_ID_OPTIONAL_COMMUNITY.source}|all|preview/.freeze
    HEX_COLOR = /^\#[a-fA-F0-9]{6}$/.freeze
    TARGET_OR_TERRITORY_ID = /#{TARGET.source}|#{TERRITORY_ID.source}/.freeze
  end
end


# this.regex = {
#   serverID: {
#     base: /[^\s]+_[^\s]+/i,
#     only: /^[^\s]+_[^\s]+$/i
#   },
#   broadcast: {
#     base: /(?:[^\s]+_[^\s]+)|all|test/i,
#     only: /(?:^[^\s]+_[^\s]+$)|^all$|^test$/i
#   },
#   communityID: {
#     base: /[^\s]+/i,
#     only: /^[^\s]+$/i
#   },
#   steamUID: {
#     base: /\d{17}/i,
#     only: /^\d{17}$/i
#   },
#   target: {
#     base: /\d{17}|<@!?\d+>/i,
#     only: /^\d{17}$|^<@!?\d+>$/i
#   },
#   targetAcceptDeny: {
#     base: /\d{17}|<@!?\d+>|accept|decline/i,
#     only: /^\d{17}$|^<@!?\d+>$|^accept$|^decline$/i
#   },
#   territoryID: {
#     base: /\w+/i,
#     only: /^\w+$/i
#   },
#   discordTag: {
#     base: /<@!?\d+>/i,
#     only: /^<@!?\d+>$/i
#   },
#   discordID: {
#     base: /\d{18}/i,
#     only: /^\d{18}$/i
#   },
#   targetOrTerritory: {
#     base: /\d{17}|<@!?\d+>|\w+/i,
#     only: /^\d{17}|<@!?\d+>|\w+$/i
#   },
#   acceptDecline: {
#     base: /accept|decline/i,
#     only: /^accept$|^decline$/i
#   }
# };
