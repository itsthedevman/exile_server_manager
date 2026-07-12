# frozen_string_literal: true

class HashType < ActiveRecord::Type::Json
  def deserialize(value)
    return value unless value.is_a?(::String)

    JSON.parse(value, symbolize_names: true)
  end
end
