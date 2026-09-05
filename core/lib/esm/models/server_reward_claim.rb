# frozen_string_literal: true

module ESM
  class ServerRewardClaim < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================
    include RewardContents

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :server_id, :integer
    attribute :user_id, :integer

    # The package this claim came from, kept for the cooldown's scope key rather than as a link back to the package.
    # Nil for a claim an admin built by hand, which puts nothing on cooldown when it settles.
    attribute :reward_id, :string

    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0

    # Keyed by class name, valued by quantity. The keys are data rather than structure, so they come back as symbols
    # the same as everything else :hash deserializes; ESM::Arma::ClassLookup.find calls to_s for exactly that reason.
    attribute :items, :hash, default: {}

    # Valid attributes:
    #   class_name <String>
    #   spawn_location <String> Valid options: "nearby", "virtual_garage", "player_decides"
    #   territory_id <String> Encoded, supplied at delivery. Only for "virtual_garage"
    #   pin_code <String> Four digits, supplied at delivery
    attribute :vehicles, :hash, default: []

    # failed is a stop, not a loss. The claim still owes the player; they have just tried enough times that the next
    # move belongs to someone who can see why. Admins clear it back to waiting from the website.
    enum :state, {waiting: "waiting", in_flight: "in_flight", failed: "failed"}
    attribute :state_details, :hash, default: {}
    attribute :attempt_count, :integer, default: 0
    attribute :last_attempt_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

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

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def contents
      @contents ||= {
        player_poptabs:,
        locker_poptabs:,
        respect:,
        items: describe_items(items),
        vehicles: describe_vehicles(vehicles)
      }.to_datum
    end
  end
end
