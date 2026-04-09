# frozen_string_literal: true

module Discordrb
  class Member
    def to_h
      {
        id: id.to_s,
        username: username
      }
    end

    alias_method :attributes, :to_h
  end
end
