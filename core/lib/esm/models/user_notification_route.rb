# frozen_string_literal: true

module ESM
  class UserNotificationRoute < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    TYPES = %w[
      custom
      base-raid
      flag-stolen
      flag-restored
      flag-steal-started
      protection-money-due
      protection-money-paid
      grind-started
      hack-started
      charge-plant-started
      marxet-item-sold
    ].freeze

    GROUPS = {
      territory_management: %w[
        flag-restored
        protection-money-due
        protection-money-paid
      ],
      base_combat: %w[
        base-raid
        flag-stolen
        flag-steal-started
        grind-started
        hack-started
        charge-plant-started
      ],
      economy: %w[
        marxet-item-sold
      ],
      custom: %w[
        custom
      ]
    }.freeze

    TYPE_TO_GROUP = {
      "flag-restored" => :territory_management,
      "protection-money-due" => :territory_management,
      "protection-money-paid" => :territory_management,
      "base-raid" => :base_combat,
      "flag-stolen" => :base_combat,
      "flag-steal-started" => :base_combat,
      "grind-started" => :base_combat,
      "hack-started" => :base_combat,
      "charge-plant-started" => :base_combat,
      "marxet-item-sold" => :economy,
      "custom" => :custom
    }.freeze

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :public_id, :uuid
    attribute :user_id, :integer
    attribute :source_server_id, :integer # nil means "any server"
    attribute :destination_community_id, :integer
    attribute :channel_id, :string
    attribute :notification_type, :string
    attribute :enabled, :boolean, default: true
    attribute :user_accepted, :boolean, default: false
    attribute :community_accepted, :boolean, default: false
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :user
    belongs_to :destination_community, class_name: "Community"
    belongs_to :source_server, class_name: "Server", optional: true

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    validates :public_id, :user_id, :destination_community_id, :channel_id, presence: true
    validates :notification_type,
      presence: true,
      uniqueness: {
        scope: %i[user_id destination_community_id source_server_id channel_id]
      }

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    before_validation :create_uuid, on: :create

    # =============================================================================
    # SCOPES
    # =============================================================================

    scope :enabled, -> { where(enabled: true) }
    scope :accepted, -> { where(user_accepted: true, community_accepted: true) }
    scope :pending_community_acceptance, -> { where(user_accepted: true, community_accepted: false) }
    scope :pending_user_acceptance, -> { where(user_accepted: false, community_accepted: true) }

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def global?
      source_server_id.nil?
    end

    private

    def create_uuid
      self.public_id = SecureRandom.uuid
    end
  end
end
