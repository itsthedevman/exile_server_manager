# frozen_string_literal: true

module ESM
  class User < ApplicationRecord
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

    has_many :gamble_stats
    has_many :user_notification_preferences
    has_many :cooldowns
    has_many :my_requests, foreign_key: :requestor_user_id, class_name: "Request"
    has_many :pending_requests, foreign_key: :requestee_user_id, class_name: "Request"

    attr_accessor :GUILD_TYPE if ENV["ESM_ENV"] == "test"

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

    def self.parse(input)
      return nil if input.nil?

      # In case of frozen strings
      input = input.dup if input.frozen?

      # in case of ints
      input = input.to_s if !input.is_a?(String)

      # Break the steam_uid or discord tag down to a discord id
      discord_id =
        if ESM::Regex::DISCORD_TAG_ONLY =~ input
          input.gsub(/[<@!&>]/, "")
        elsif ESM::Regex::STEAM_UID_ONLY =~ input
          db_user = self.find_by_steam_uid(input)
          db_user&.discord_id
        else
          input
        end

      # Return the discord user
      build(discord_id, db_user)
    rescue StandardError
      nil
    end

    def self.build(discord_id, db_user)
      db_user = self.find_by_discord_id(discord_id) if db_user.nil?

      # Get the user from discord and add our information
      discord_user = ESM.bot.user(discord_id)

      # We didn't find someone in the DB, just return what we have
      return discord_user if db_user.nil?

      # Save some data for later consumption
      discord_user.steam_uid = db_user.steam_uid
      discord_user.instance_variable_set("@esm_user", db_user)

      # Return the discord user
      discord_user
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

    def registered?
      steam_uid.present?
    end

    def developer?
      [Bryan::ID, BryanV2::ID].include?(discord_id)
    end

    def mention
      "<@#{discord_id}>"
    end

    def discord_user
      @discord_user ||= ESM.bot.user(discord_id)
    end
  end
end
