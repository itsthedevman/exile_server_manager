# frozen_string_literal: true

module Discordrb
  class Channel
    TYPE_NAMES = {
      0 => :text,
      1 => :dm,
      2 => :voice,
      3 => :group,
      4 => :category
    }.freeze

    def to_h
      {
        id: id.to_s,
        name: name,
        position: position,
        type: TYPE_NAMES[type],
        category: category&.to_h
      }
    end

    alias_method :attributes, :to_h
  end
end
