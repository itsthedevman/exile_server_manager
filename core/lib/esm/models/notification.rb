# frozen_string_literal: true

module ESM
  class Notification < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    DEFAULTS = YAML.safe_load_file(
      File.join(
        File.expand_path("..", __dir__),
        "defaults/notifications.yml"
      )
    ).freeze

    CATEGORIES = %w[xm8 gambling player].freeze

    TYPES = %w[
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
      loss
      won
      money
      locker
      respect
      heal
      kill
    ].freeze

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :public_id, :string
    attribute :community_id, :integer
    attribute :notification_type, :string
    attribute :notification_title, :text
    attribute :notification_description, :text
    attribute :notification_color, :string
    attribute :notification_category, :string
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

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

    scope :with_category, ->(notification_category) { where(notification_category:) }
    scope :with_type, ->(notification_type) { where(notification_type:) }
    scope :with_any_type, ->(*types) { where(notification_type: types) }

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    def self.build_random(community_id:, type:, category:, **)
      notification = where(
        community_id: community_id,
        notification_type: type,
        notification_category: category
      ).sample

      # Grab a default if one was not found
      if notification.nil?
        default = DEFAULTS[category]
          .select { |n| n["type"] == type }
          .sample
          .transform_keys { |k| "notification_#{k}" }

        notification = new(default)
      end

      notification.build_embed(**)
    end

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================
  end
end
