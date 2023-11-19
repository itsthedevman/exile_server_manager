# frozen_string_literal: true

module ESM
  class CommandDetail < ApplicationRecord
    attribute :command_name, :string
    attribute :command_type, :string
    attribute :command_category, :string
    attribute :command_limited_to, :string
    attribute :command_description, :text
    attribute :command_usage, :text
    attribute :command_examples, :json
    attribute :command_arguments, :json
    attribute :command_attributes, :json
    attribute :command_requirements, :json
  end
end
