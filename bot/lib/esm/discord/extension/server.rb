# frozen_string_literal: true

module Discordrb
  class Server
    def to_h
      {
        id: id.to_s,
        name: name
      }
    end

    alias_method :attributes, :to_h
  end
end
