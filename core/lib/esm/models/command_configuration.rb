# frozen_string_literal: true

module ESM
  class CommandConfiguration < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :community_id, :integer
    attribute :command_name, :string
    attribute :enabled, :boolean, default: true
    attribute :notify_when_disabled, :boolean, default: true
    attribute :cooldown_quantity, :integer, default: 2
    attribute :cooldown_type, :string, default: "seconds"
    attribute :allowed_in_text_channels, :boolean, default: true
    attribute :allowlist_enabled, :boolean, default: false
    attribute :allowlisted_role_ids, :json, default: []
    attribute :created_at, :datetime
    attribute :updated_at, :datetime
    attribute :deleted_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :community

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

    def allowlisted_roles
      @allowlisted_roles ||= lambda do
        allowlisted_role_ids.filter_map do |id|
          role = community.roles.find { |r| r.id == id }
          next if role.nil?

          role
        end
      end.call
    end

    def details
      CommandDetail.where(command_name: command_name).first
    end
  end
end
