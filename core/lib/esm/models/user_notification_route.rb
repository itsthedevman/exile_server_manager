# frozen_string_literal: true

module ESM
  class UserNotificationRoute < ESM::ApplicationRecord
    attribute :uuid, :uuid
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

    belongs_to :user
    belongs_to :destination_community, class_name: "Community"
    belongs_to :source_server, class_name: "Server", optional: true

    validates :uuid, :user_id, :destination_community_id, :channel_id, presence: true
    validates :notification_type, presence: true, uniqueness: {scope: %i[user_id destination_community_id source_server_id channel_id]}

    before_create :create_uuid

    scope :enabled, -> { where(enabled: true) }
    scope :accepted, -> { where(user_accepted: true, community_accepted: true) }
    scope :pending_community_acceptance, -> { where(user_accepted: true, community_accepted: false) }
    scope :pending_user_acceptance, -> { where(user_accepted: false, community_accepted: true) }

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

    TYPE_PRESETS = {
      raids: %w[
        base-raid
        flag-stolen
        flag-restored
        flag-steal-started
        grind-started
        hack-started
        charge-plant-started
      ].freeze,
      payments: %w[
        protection-money-due
        protection-money-paid
      ].freeze
    }.freeze

    private

    def create_uuid
      self.uuid = SecureRandom.uuid
    end
  end
end
