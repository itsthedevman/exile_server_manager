# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    attr_reader :accepted

    # https://english.stackexchange.com/a/29258 @GEdgars comment
    attribute :uuid, :uuid
    attribute :uuid_short, :string
    attribute :requestor_user_id, :integer
    attribute :requestee_user_id, :integer
    attribute :requested_from_channel_id, :string
    attribute :command_name, :string
    attribute :command_arguments, :json, default: nil
    attribute :expires_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :requestor, class_name: "User", foreign_key: "requestor_user_id"
    belongs_to :requestee, class_name: "User", foreign_key: "requestee_user_id"

    before_validation :set_uuid, on: :create
    before_validation :set_expiration_date, on: :create

    validates :uuid_short, format: { with: /[0-9a-fA-F]{4}/ }

    scope :expired, -> { where("expires_at <= ?", DateTime.current) }

    def respond(accepted)
      @accepted = accepted

      # Build the command
      command = ESM::Command[self.command_name].new

      # Respond
      command.from_request(self)

      # Remove the request
      self.destroy
    end

    private

    def set_uuid
      self.uuid = SecureRandom.uuid
      self.uuid_short = self.uuid[9..12]
    end

    def set_expiration_date
      self.expires_at = ::Time.current + 1.day
    end
  end
end
