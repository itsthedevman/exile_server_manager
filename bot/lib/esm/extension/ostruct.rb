# frozen_string_literal: true

class OpenStruct
  def blank?
    self.to_h.blank?
  end

  def to_h
    hash = {}

    self.marshal_dump.each do |key, value|
      hash[key] =
        if value.is_a?(OpenStruct)
          value.to_h
        elsif value.is_a?(ActiveSupport::Duration)
          value.parts
        else
          value
        end
    end

    hash
  end
end
