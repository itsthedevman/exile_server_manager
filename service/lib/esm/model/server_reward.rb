# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
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
