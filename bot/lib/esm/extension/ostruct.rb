# frozen_string_literal: true

class OpenStruct
  attr_reader :table

  def blank?
    table.blank?
  end

  def each(&block)
    return self if !block.present?

    # Loop over each key and call the passed block with the key and the original value
    # This means nested OpenStructs stay as OpenStructs
    to_h.each_key do |key|
      yield(key.to_s, self[key])
    end

    self
  end

  def map(&block)
    return [] if !block.present?

    # Loop over each key and call the passed block with the key and the original value
    # This means nested OpenStructs stay as OpenStructs
    to_h.keys.map do |key|
      yield(key.to_s, self[key])
    end
  end

  def to_ostruct
    self
  end
end
