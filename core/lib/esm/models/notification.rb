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

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

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

    # TODO: REPLACE
    def public_id
      SecureRandom.uuid
    end
  end
end
