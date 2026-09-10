# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================
    include RewardContents

    VEHICLE_SPAWN_LOCATIONS = %w[nearby virtual_garage player_decides].freeze

    # A player has to be told this code somewhere and then type it back, so it is held to a length that survives both
    REWARD_ID_MAX_LENGTH = 27

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

    # Keyed by class name, valued by quantity. The keys are data rather than structure, so they come back as symbols
    # the same as everything else :hash deserializes; ESM::Arma::ClassLookup.find calls to_s for exactly that reason.
    attribute :reward_items, :hash, default: {}

    # Valid attributes:
    #   class_name <String>
    #   spawn_location <String> Valid options: See VEHICLE_SPAWN_LOCATIONS
    attribute :reward_vehicles, :hash, default: []
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :server

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # Only checked when it changes. A package created before there was any way to edit one may hold anything, and an
    # owner who opens it to fix a poptab amount should not be stopped by a code they never chose.
    validates :reward_id,
      presence: true,
      length: {maximum: REWARD_ID_MAX_LENGTH},
      format: {
        with: /\A[a-z0-9_-]+\z/,
        message: "may only contain lowercase letters, numbers, underscores and dashes"
      },
      uniqueness: {scope: :server_id, message: "is already used by another package on this server"},
      if: :reward_id_changed?

    validates :player_poptabs, :locker_poptabs, :respect, numericality: {greater_than_or_equal_to: 0}

    validates :cooldown_type, inclusion: {in: ESM::Cooldown::TYPES}, allow_blank: true
    validates :cooldown_quantity, numericality: {greater_than: 0}, allow_nil: true

    validate :cooldown_is_whole_or_absent

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

    ##
    # Whether this is the package a player gets for asking without naming one. Every server has exactly one, created
    # with the server, and it is the only package that cannot be deleted or renamed.
    #
    # @return [Boolean]
    #
    def default?
      reward_id == "default"
    end

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
    # @return [ActiveSupport::Duration, nil] nil when this package sets no cooldown of its own, in which case the
    #   community's configuration for the command decides
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

    private

    # Half a cooldown is worse than none: a quantity with no unit cannot be turned into a duration, and a unit with no
    # quantity silently falls back to whatever the community configured for the command.
    def cooldown_is_whole_or_absent
      return if cooldown_quantity.blank? == cooldown_type.blank?

      errors.add(:cooldown_quantity, "and a unit have to be set together, or neither")
    end
  end
end
