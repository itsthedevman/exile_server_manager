# frozen_string_literal: true

module ESM
  class CommandCount < ApplicationRecord
    attribute :command_name, :string
    attribute :execution_count, :integer

    def self.increment_execution_counter(command_name)
      # Single quotes are required for strings, double quotes are for columns
      self.connection.execute(
        "UPDATE command_counts SET execution_count = COALESCE(\"execution_count\", 0) + 1 WHERE command_name = '#{command_name}';"
      )
    end
  end
end
