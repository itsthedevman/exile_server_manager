# frozen_string_literal: true

class ServerCreateEvent
  # Can't use initializer because I want to return a different object. This is essentially a wrapper
  def self.create
    data = {
      "id" => ESM::Community::ESM::ID
    }

    Discordrb::Events::ServerCreateEvent.new(data, ESM.bot)
  end
end
