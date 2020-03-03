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
  end
end
