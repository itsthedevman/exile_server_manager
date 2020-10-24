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

    # Log Parsing
    LOG_TIMESTAMP = /\[(?<time>\d{2}:\d{2}:\d{2}):\d{6} (?<zone>[-+]?\d{2}:\d{2})\] \[thread \d+\] /i.freeze
  end
end
