# frozen_string_literal: true

module ESM
  class User < ApplicationRecord
    after_create :create_user_steam_data

    attribute :discord_id, :string
    attribute :discord_username, :string
    attribute :discord_discriminator, :string
    attribute :discord_avatar, :text, default: nil
    attribute :discord_access_token, :string, default: nil
    attribute :discord_refresh_token, :string, default: nil
    attribute :steam_uid, :string, default: nil
    attribute :steam_username, :string, default: nil
    attribute :steam_avatar, :text, default: nil
    attribute :steam_profile_url, :text, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    has_one :user_steam_data
    has_many :user_gamble_stats
    has_many :user_notification_preferences
    has_many :cooldowns
    has_many :my_requests, foreign_key: :requestor_user_id, class_name: "Request"
    has_many :pending_requests, foreign_key: :requestee_user_id, class_name: "Request"

    attr_accessor :GUILD_TYPE if ESM.env.test?

    module Bryan
      ID = "137709767954137088"
      USERNAME = "Bryan"
      DISCRIMINATOR = "9876"
      MENTION = "<@#{ID}>"
      STEAM_UID = "76561198037177305"
      STEAM_USERNAME = "WolfkillArcadia"
    end

    module BryanV2
      ID = "477847544521687040"
      USERNAME = "Bryan v2"
      DISCRIMINATOR = "2145"
      MENTION = "<@#{ID}>"

      # Tks Andrew
      STEAM_UID = "76561198025434405"
      STEAM_USERNAME = "Andrew_S90"
    end

    module BryanV3
      ID = "477847544521687040"
      USERNAME = "Bryan v3"
      DISCRIMINATOR = "2369"
      MENTION = "<@#{ID}>"

      # Tks Adam
      STEAM_UID = "76561198073495490"
      STEAM_USERNAME = "Adam Kadmon"
    end

    #########################
    # Public Methods
    #########################

    # Parses and finds a user based off of SteamUID, Discord ID, or Discord Mention
    def self.parse(input)
      return nil if input.nil?

      # In case of frozen strings
      input = input.dup if input.frozen?

      # Discordrb stores the Discord ID as an Integer.
      input = input.to_s if !input.is_a?(String)

      if ESM::Regex::DISCORD_TAG_ONLY.match(input)
        # Remove the extra stuff from a mention
        self.find_by_discord_id(input.gsub(/[<@!&>]/, ""))
      elsif ESM::Regex::STEAM_UID_ONLY.match(input)
        self.find_by_steam_uid(input)
      else
        self.find_by_discord_id(input)
      end
    end

    def self.find_by_steam_uid(uid)
      order(:steam_uid).where(steam_uid: uid).first
    end

    def self.find_by_discord_id(id)
      id = id.to_s if !id.is_a?(String)
      order(:discord_id).where(discord_id: id).first
    end

    #########################
    # Instance Methods
    #########################

    def steam_data
      @steam_data ||= lambda do
        # If the data is stale, it will automatically refresh
        self.user_steam_data.refresh
        self.user_steam_data
      end.call
    end

    def registered?
      self.steam_uid.present?
    end

    def developer?
      [Bryan::ID, BryanV2::ID].include?(self.discord_id)
    end

    def mention
      "<@#{self.discord_id}>"
    end

    def discord_user
      @discord_user ||= lambda do
        discord_user = ESM.bot.user(self.discord_id)
        return if discord_user.nil?

        # Keep the user up-to-date
        Thread.new do
          self.update(discord_username: discord_user.username, discord_discriminator: discord_user.discriminator, discord_avatar: discord_user.avatar_url)
        end

        # Save some data for later consumption
        discord_user.steam_uid = self.steam_uid
        discord_user.instance_variable_set("@esm_user", self)

        discord_user
      end.call
    end
  end
end
