# frozen_string_literal: true

module RewardContents
  private

  def describe_vehicles(vehicle_array)
    vehicle_array.map do |vehicle_data|
      vehicle_data = vehicle_data.with_indifferent_access

      class_name = vehicle_data[:class_name]
      spawn_location = vehicle_data[:spawn_location]
      display_name = display_name_for(class_name)

      {class_name:, display_name:, spawn_location:}.to_datum
    end
  end

  def describe_items(item_hash)
    item_hash.map do |class_name, quantity|
      display_name = display_name_for(class_name)

      {class_name:, display_name:, quantity:}.to_datum
    end
  end

  def display_name_for(class_name)
    ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name
  end
end
