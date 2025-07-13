# frozen_string_literal: true

module ESM
  class LogEntry < ApplicationRecord
    before_create :generate_uuid

    attribute :uuid, :uuid
    attribute :log_id, :integer
    attribute :file_name, :string
    attribute :entries, :json

    # V1
    attribute :log_date, :datetime, default: nil

    belongs_to :log

    private

    def generate_uuid
      self.uuid = SecureRandom.uuid
    end
  end
end
