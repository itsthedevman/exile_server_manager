# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================
    include RewardContents

    VEHICLE_SPAWN_LOCATIONS = %w[nearby virtual_garage player_decides].freeze

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :server_id, :integer
    attribute :reward_id, :string
    attribute :name, :string
    attribute :enabled, :boolean
    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0

    # Valid attributes:
    #   class_name <String>
    #   quantity <Integer>
    attribute :reward_items, :json, default: {}

    # Valid attributes:
    #   class_name <String>
    #   spawn_location <String> Valid options: See VEHICLE_SPAWN_LOCATIONS
    attribute :reward_vehicles, :json, default: []
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :server
    belongs_to :user

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    # =============================================================================
    # SCOPES
    # =============================================================================

    scope :default, -> { where(reward_id: "default") }
    scope :enabled, -> { where(enabled: true) }

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def rewards?
      locker_poptabs.positive? ||
        player_poptabs.positive? ||
        respect.positive? ||
        reward_items.present? ||
        reward_vehicles.present?
    end

    ##
    # This package's cooldown as a duration, recomposed from the two columns that store it. Mirrors
    # ESM::Command::Permission#cooldown_time so both sources of a cooldown length answer in the same shape.
    #
    # @return [ActiveSupport::Duration, nil] nil when the server owner never configured a cooldown for this package
    #
    def cooldown_time
      return if cooldown_quantity.blank? || cooldown_type.blank?

      # [2, "seconds"] -> 2.seconds. Calls .seconds, .minutes, .days, etc.
      cooldown_quantity.send(cooldown_type)
    end

    def contents
      @contents ||= {
        player_poptabs:,
        locker_poptabs:,
        respect:,
        items: describe_items(reward_items),
        vehicles: describe_vehicles(reward_vehicles)
      }.to_datum
    end
  end
end
