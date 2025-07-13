# frozen_string_literal: true

module ESM
  class CommandCount < ApplicationRecord
    attribute :command_name, :string
    attribute :execution_count, :integer

    def self.increment_execution_counter(command_name)
      Thread.new do
        where(command_name: name).update_counters(execution_count: 1)
      end
    end
  end
end
