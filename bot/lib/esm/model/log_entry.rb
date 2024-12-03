# frozen_string_literal: true

module ESM
  class LogEntry < ApplicationRecord
    attribute :log_id, :integer
    attribute :file_name, :string
    attribute :entries, :json

    # V1
    attribute :log_date, :datetime, default: nil

    belongs_to :log
  end
end
