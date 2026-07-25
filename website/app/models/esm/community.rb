# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    public_attributes(
      :community_id, :community_name,
      id: ->(community) { community.public_id }
    )

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    # =============================================================================
    # SCOPES
    # =============================================================================

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def server_mode_enabled?
      !player_mode_enabled?
    end

    def modifiable_by?(user)
      ESM::Service::API.call(:community_modifiable_by, id:, user_id: user.id) || false
    end

    #
    # Channel/Category: {id:, name:, position:, type:, ?category:}
    #
    # [
    #   [{name: <discord_server_name>}, Array<Channel>] # Un-categorized channels
    #   [category_hash, Array<Channel>]... # Categories + channels
    # ]
    def channels
      @channels ||= ESM::Service::API.call(:community_channels, id:, user_id: nil) || []
    end

    def player_channels(user)
      @player_channels ||= ESM::Service::API.call(:community_channels, id:, user_id: user.id) || []
    end

    def roles
      @roles ||= (ESM::Service::API.call(:community_roles, id:) || []).map(&:to_struct)
    end

    #
    # A user's Discord membership in this community: the ids of the roles they hold and whether they hold Discord's
    # administrator permission. This is the allowlist input the website can't read from the database - only the bot can
    # see Discord role membership - so command permission checks source it here. An unseeable guild or membership
    # degrades to an empty membership, which reads as "holds no allowlisted role".
    #
    # @param user [ESM::User]
    #
    # @return [Struct] responds to #role_ids ([String]) and #administrator (Boolean)
    #
    def membership_for(user)
      payload = ESM::Service::API.call(:community_membership, user_id: user.id, community_id: id)
      (payload || {role_ids: [], administrator: false}).to_struct
    end

    #
    # Removes this community: the bot leaves the guild and the record is destroyed.
    # Returns false when the user lacks modify rights.
    #
    def leave(by:)
      ESM::Service::API.call(:community_delete, id:, user_id: by.id) || false
    end

    def territory_admins
      validate_and_decorate_roles(territory_admin_ids)
    end

    def dashboard_admins
      validate_and_decorate_roles(dashboard_access_role_ids)
    end

    ##
    # This community's territory-admin users: members holding a Discord administrator role or one of the community's
    # configured territory-admin roles, plus the guild owner. Only the bot can resolve Discord role membership, so it
    # computes the set and writes the resolved ids to the store this app shares with it; this reads them back, warming a
    # cold key through the bot on first read (a server up long enough for the entry to lapse without a reboot to refresh
    # it). Memoized per instance.
    #
    # @return [ActiveRecord::Relation<ESM::User>] the territory-admin users; empty when the community has none or the
    #   bot can't be reached
    #
    def territory_admin_users
      @territory_admin_users ||=
        ESM::User.where(id: ESM.cache.read(territory_admin_users_cache_key) || warm_territory_admin_ids).load
    end

    #
    # Whether the user holds territory-admin rights in this community. A territory admin gets write access to every
    # territory's web actions (arma still enforces the actual in-game rights), a broader grant than access to a single
    # command like info.
    #
    # @param user [ESM::User]
    #
    # @return [Boolean]
    #
    def territory_admin?(user)
      territory_admin_users.include?(user)
    end

    def update_community_id!(new_id)
      # Adjust the server IDs
      ESM::Server.where(community_id: id).each do |server|
        old_id = server.server_id
        server.update(server_id: server.server_id.gsub("#{community_id}_", "#{new_id}_"))

        # Force the server to reconnect
        server.reconnect(old_id)
      end

      update!(community_id: new_id)
    end

    private

    # Asks the bot to compute the territory-admin users (which repopulates the shared cache for later reads) and hands
    # back their ids. A down or unreachable bot fails closed - an empty list reads as "not a territory admin" - so a
    # transient outage denies the elevated action rather than 500ing the page.
    def warm_territory_admin_ids
      ESM::Service::API.call(:territory_admins, community_id: id) || []
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      Rails.logger.warn("[territory_admin_uids] warm failed: #{e.message}")
      []
    end

    def validate_and_decorate_roles(role_ids)
      return [] if role_ids.blank?

      role_ids.map do |id|
        role = roles.find { |r| r.id == id }
        next role_ids.delete(id) if role.nil?

        role
      end
    end
  end
end
