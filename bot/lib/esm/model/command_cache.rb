# frozen_string_literal: true

module ESM
  class CommandCache < ApplicationRecord
    attribute :command_name, :string
    attribute :command_type, :string
    attribute :command_category, :string
    attribute :command_description, :text
    attribute :command_example, :text
    attribute :command_usage, :text
    attribute :command_arguments, :text
    attribute :command_aliases, :json
  end
end
