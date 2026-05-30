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
