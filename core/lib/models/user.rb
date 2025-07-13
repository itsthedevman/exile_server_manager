# frozen_string_literal: true

module ESM
  class User < ApplicationRecord
    attr_writer :discord_user

    after_create :create_user_steam_data
    after_create :create_id_defaults

    attribute :discord_id, :string
    attribute :discord_username, :string
    attribute :discord_avatar, :text, default: nil
    attribute :discord_access_token, :string, default: nil
    attribute :discord_refresh_token, :string, default: nil
    attribute :steam_uid, :string, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    alias_attribute :avatar_url, :discord_avatar
    alias_attribute :distinct, :discord_username
    alias_attribute :username, :discord_username

    has_many :cooldowns, dependent: :nullify
    has_many :id_aliases, class_name: "UserAlias", dependent: :destroy
    has_one :id_defaults, class_name: "UserDefault", dependent: :destroy
    has_many :logs, class_name: "Log", foreign_key: "requestors_user_id", dependent: :destroy
    has_many :my_requests, foreign_key: :requestor_user_id, class_name: "Request", dependent: :destroy
    has_many :pending_requests, foreign_key: :requestee_user_id, class_name: "Request", dependent: :destroy
    has_many :user_gamble_stats, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy
    has_many :user_notification_routes, dependent: :destroy
    has_one :user_steam_data, dependent: :destroy

    # validates :discord_id, uniqueness: true, presence: true
    # validates :steam_uid, uniqueness: true

    delegate :on, to: :discord_user, allow_nil: true

    #########################
    # Public Methods
    #########################

    # Parses and finds a user based off of SteamUID, Discord ID, or Discord Mention
    def self.parse(input)
      return if input.nil?

      # In case of frozen strings
      input = input.dup if input.frozen?

      # Discordrb stores the Discord ID as an Integer.
      input = input.to_s if !input.is_a?(String)

      if ESM::Regex::DISCORD_TAG_ONLY.match?(input)
        # Remove the extra stuff from a mention
        find_by_discord_id(input.gsub(/[<@!&>]/, ""))
      elsif input.steam_uid?
        find_by_steam_uid(input)
      else
        find_by_discord_id(input)
      end
    end

    def self.from_discord(discord_user)
      return if discord_user.nil?

      user = order(:discord_id)
        .where(discord_id: discord_user.id)
        .first_or_initialize

      user.update!(discord_username: discord_user.username, discord_avatar: discord_user.avatar_url)
      user.discord_user = discord_user
      user
    end

    def self.find_by_steam_uid(uid)
      order(:steam_uid).where(steam_uid: uid).first
    end

    def self.find_by_discord_id(id)
      id = id.to_s unless id.is_a?(String)
      order(:discord_id).where(discord_id: id).first
    end

    #########################
    # Instance Methods
    #########################

    def attributes_for_logging
      attributes.except("id", "discord_avatar", "discord_access_token", "discord_refresh_token", "updated_at")
    end

    def steam_data
      @steam_data ||= user_steam_data&.refresh
    end

    def registered?
      steam_uid.present?
    end

    def developer?
      ESM.config.dev_user_allowlist.include?(discord_id)
    end

    def mention
      "<@#{discord_id}>"
    end
    alias_method :discord_mention, :mention

    def discord_user
      return if discord_id.nil?

      @discord_user ||= lambda do
        discord_user = ESM.bot.user(discord_id)
        return if discord_user.nil?

        # Keep the discord user data up-to-date
        incoming_attributes = [discord_user.username, discord_user.avatar_url]
        current_attributes = [discord_username, discord_avatar]

        if current_attributes != incoming_attributes
          update!(
            discord_username: discord_user.username,
            discord_avatar: discord_user.avatar_url
          )
        end

        # Save some data for later consumption
        discord_user.esm_user = self
        discord_user
      end.call
    end

    def discord_servers
      return if discord_id.nil?

      @discord_servers ||= ESM.bot.servers.values.select do |server|
        server.users.any? { |user| user.id.to_s == discord_id }
      end
    end

    def can_modify?(guild_id)
      return false if discord_id.nil?
      return true if developer? && !Rails.env.development?

      community = Community.find_by_guild_id(guild_id)
      return false if community.nil?

      server = community.discord_server
      return false if server.nil?

      # Check if they're the owner or admin
      community.modifiable_by?(on(server))
    end

    def channel_permission?(permission, channel)
      !!on(channel.server)&.permission?(permission, channel)
    end
  end
end
