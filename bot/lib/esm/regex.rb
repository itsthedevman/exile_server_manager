# frozen_string_literal: true

module ESM
  module Regex
    COMMUNITY_ID_OPTIONAL = /[^\s]*/i
    COMMUNITY_ID = /[^\s]+/i
    DISCORD_TAG = /<@[&!]?\d+>/
    DISCORD_TAG_ONLY = /^#{DISCORD_TAG.source}$/
    DISCORD_ID = /\d{18,19}/
    DISCORD_ID_ONLY = /^#{DISCORD_ID.source}$/
    STEAM_UID = /\d{17}/
    STEAM_UID_ONLY = /^#{STEAM_UID.source}$/
    TARGET = /#{DISCORD_TAG.source}|#{DISCORD_ID.source}|#{STEAM_UID.source}/
    SERVER_ID_OPTIONAL_COMMUNITY = /(?:[^\s]+_)*[^\s]+/
    SERVER_ID = /[^\s]+_[^\s]+/
    SERVER_ID_ONLY = /^#{SERVER_ID.source}$/
    TERRITORY_ID = /\w+/
    TERRITORY_ID_ONLY = /^#{TERRITORY_ID.source}$/
    FLAG_NAME = /(flag_.*)\.paa/
    BROADCAST = /#{SERVER_ID_OPTIONAL_COMMUNITY.source}|all|preview/
    HEX_COLOR = /^\#[a-fA-F0-9]{6}$/
    TARGET_OR_TERRITORY_ID = /#{TARGET.source}|#{TERRITORY_ID.source}/
    REWARD_ID = /[^\s]+/
    REWARD_ID_ONLY = /^#{REWARD_ID.source}$/

    # Log Parsing
    LOG_TIMESTAMP = /\[(?<time>\d{2}:\d{2}:\d{2}):\d{6} (?<zone>[-+]?\d{2}:\d{2})\] \[thread \d+\] /i
  end
end
