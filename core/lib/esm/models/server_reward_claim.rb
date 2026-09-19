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

    ##
    # Stops every delivery that was still running when this process last went down.
    #
    # Nothing can be mid-delivery at boot, so a claim found in flight here belongs to one that died with whatever was
    # carrying it. What it managed to hand over before that is unknown, which is an admin's call rather than something
    # to quietly attempt again.
    #
    # @return [void]
    #
    def self.settle_interrupted_deliveries!
      in_flight.find_each do |claim|
        claim.interrupt!("the bot restarted before this finished")
      end
    end

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    ##
    # Stops this claim on a delivery that never said how it went, recording why.
    #
    # The reason joins whatever the last attempt already reported, so a claim that came back holding leftovers still
    # says why those are here alongside why nobody knows how this attempt ended.
    #
    # @param reason [String] what happened, in the words the claim's failures are written in
    #
    # @return [void]
    #
    def interrupt!(reason)
      failures = Array(state_details[:failures]) + [{bucket: "delivery", name: "Delivery", reason:}]

      update!(state: :failed, state_details: {failures:})
    end

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
