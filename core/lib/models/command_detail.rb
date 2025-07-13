# frozen_string_literal: true

module ESM
  class CommandDetail < ApplicationRecord
    attr_reader :configuration

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

    def self.total
      @total ||= all.size
    end

    def preload(community)
      @configuration = community.command_configurations.where(command_name: command_name).first
    end

    def modifiable?
      command_attributes.any? { |_key, attrs| attrs["modifiable"] }
    end
  end
end
