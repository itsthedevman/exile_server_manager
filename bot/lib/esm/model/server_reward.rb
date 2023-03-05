# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    attribute :server_id, :integer
    attribute :reward_id, :string

    # Valid attributes:
    #   class_name <String>
    #   quantity <Integer>
    attribute :reward_items, :json, default: {}

    # Valid attributes:
    #   class_name <String>
    #   spawn_location <String> Valid options: "nearby", "virtual_garage", "player_decides"
    attribute :reward_vehicles, :json, default: []

    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string

    belongs_to :server

    scope :default, -> { where(reward_id: nil).first }

    def vehicles
      @vehicles ||= reward_vehicles.map do |vehicle_data|
        vehicle_data = vehicle_data.with_indifferent_access

        class_name = vehicle_data[:class_name]
        spawn_location = vehicle_data[:spawn_location]
        display_name = ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name

        {class_name: class_name, display_name: display_name, spawn_location: spawn_location}
      end
    end

    def items
      @items ||= reward_items.map do |class_name, quantity|
        display_name = ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name

        {class_name: class_name, display_name: display_name, quantity: quantity}
      end
    end
  end
end
