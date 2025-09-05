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
      ESM.bot.community_modifiable_by?(id, user.id)
    end

    def channels
      @channels ||= ESM.bot.community_channels(id)
    end

    def player_channels(user)
      @player_channels ||= ESM.bot.community_channels(id, user_id: user.id)
    end

    def roles
      @roles ||= ESM.bot.community_roles(id).map(&:to_struct)
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
        ESM.bot.reconnect_server(server.id, old_id)
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
