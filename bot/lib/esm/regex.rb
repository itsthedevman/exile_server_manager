# frozen_string_literal: true

module ESM
  module Regex
    COMMUNITY_ID = /[^\s]+/i.freeze
    DISCORD_TAG = /<@!?\d+>/.freeze
    DISCORD_TAG_ONLY = /^<@!?\d+>$/.freeze
    DISCORD_ID = /\d{18}/.freeze
    DISCORD_ID_ONLY = /^\d{18}$/.freeze
    STEAM_UID = /\d{17}/.freeze
    STEAM_UID_ONLY = /^\d{17}$/.freeze
    TARGET = /#{DISCORD_TAG}|#{DISCORD_ID}|#{STEAM_UID}/.freeze
    SERVER_ID = /[^\s]+_[^\s]+/.freeze
    SERVER_ID_ONLY = /^[^\s]+_[^\s]+$/.freeze
    TERRITORY_ID = /\w+/.freeze
    TERRITORY_ID_ONLY = /^\w+$/.freeze
    FLAG_NAME = /(flag_.*)\.paa/.freeze
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
