# frozen_string_literal: true

module ESM
  class LogEntry < ApplicationRecord
    attribute :log_id, :integer
    attribute :log_date, :datetime
    attribute :file_name, :string
    attribute :entries, :json

    belongs_to :logs
  end
end
