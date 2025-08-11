# frozen_string_literal: true

module ESM
  class User < ApplicationRecord
    attr_writer :discord_user

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

    #########################
    # Instance Methods
    #########################

    def developer?
      ESM.config.dev_user_allowlist.include?(discord_id)
    end

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
