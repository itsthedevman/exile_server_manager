# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    def respond(accepted)
      @accepted = accepted

      origin = ESM::Discord::Command::Origin.new(
        user: requestor,
        channel: ESM.discord_bot.channel(requested_from_channel_id)
      )

      command = ESM::Command[command_name].new(origin: origin)
      command.from_request(self)
      destroy
    end
  end
end
