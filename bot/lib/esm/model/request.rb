# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    attr_reader :accepted

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

    # https://english.stackexchange.com/a/29258 @GEdgars comment
    belongs_to :requestor, class_name: "User", foreign_key: "requestor_user_id"
    belongs_to :requestee, class_name: "User", foreign_key: "requestee_user_id"

    before_validation :set_uuid, on: :create
    before_validation :set_expiration_date, on: :create

    validates :uuid_short, format: {with: /[0-9a-fA-F]{4}/}
    scope :expired, -> { where("expires_at <= ?", DateTime.current) }

    def respond(accepted)
      @accepted = accepted

      # Build the command
      command =
        if command_name.ends_with?("v1")
          ESM::Command.get_v1(command_name).new
        else
          ESM::Command[command_name].new
        end

      # Respond
      command.timers.time!(:from_request) do
        command.from_request(self)
      end

      # Remove the request
      destroy
    end

    private

    def set_uuid
      self.uuid = SecureRandom.uuid
      self.uuid_short = uuid[9..12]
    end

    def set_expiration_date
      self.expires_at = ::Time.current + 1.day
    end
  end
end
