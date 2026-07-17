# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :uuid, :uuid
    attribute :uuid_short, :string
    attribute :requestor_user_id, :integer
    attribute :requestee_user_id, :integer
    attribute :requested_from_channel_id, :string
    attribute :command_name, :string
    attribute :command_arguments, :json, default: nil
    enum :status, {pending: "pending", accepted: "accepted", rejected: "rejected"}
    attribute :expires_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    # https://english.stackexchange.com/a/29258 @GEdgars comment
    belongs_to :requestor, class_name: "User", foreign_key: "requestor_user_id"
    belongs_to :requestee, class_name: "User", foreign_key: "requestee_user_id"

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    validates :uuid_short, format: {with: /[0-9a-fA-F]{4}/}

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    before_validation :set_uuid, on: :create
    before_validation :set_expiration_date, on: :create

    # =============================================================================
    # SCOPES
    # =============================================================================

    scope :expired, -> { where("expires_at <= ?", Time.now) }

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def accept!
      return unless pending?

      update!(status: :accepted)
      on_accept
    end

    def reject!
      return unless pending?

      update!(status: :rejected)
      on_reject
    end

    private

    def set_uuid
      self.uuid = SecureRandom.uuid
      self.uuid_short = uuid[9..12]
    end

    def set_expiration_date
      self.expires_at = ::Time.current + 1.day
    end

    def on_accept
      raise NotImplementedError
    end

    def on_reject
      raise NotImplementedError
    end
  end
end
