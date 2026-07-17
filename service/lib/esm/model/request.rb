# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    private

    def on_accept
      channel = if requested_from_channel_id
        ESM.discord_bot.channel(requested_from_channel_id)
      else
        requestor.discord_user.pm
      end

      origin = Discord::Command::Origin.new(user: requestor, channel:)

      command = ESM::Command[command_name].new(origin:)
      command.from_request(self)
    end

    alias_method :on_reject, :on_accept
  end
end
