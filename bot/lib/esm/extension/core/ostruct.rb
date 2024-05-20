# frozen_string_literal: true

class OpenStruct
  attr_reader :table

  delegate :blank?, to: :table

  def each(&block)
    return self if block.blank?

    # Loop over each key and call the passed block with the key and the original value
    # This means nested OpenStructs stay as OpenStructs
    to_h.each_key do |key|
      yield(key.to_s, self[key])
    end

    self
  end

  def map(&block)
    return [] if block.blank?

    # Loop over each key and call the passed block with the key and the original value
    # This means nested OpenStructs stay as OpenStructs
    to_h.keys.map do |key|
      yield(key.to_s, self[key])
    end
  end

  def to_ostruct
    self
  end

  def to_h
    table.each_with_object({}) do |(key, value), hash|
      key =
        if key.is_a?(OpenStruct)
          key.to_h
        else
          key
        end

      value =
        if value.is_a?(OpenStruct)
          value.to_h
        else
          value
        end

      hash[key] = value
    end
  end
end
