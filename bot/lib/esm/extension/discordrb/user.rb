# frozen_string_literal: true

module Discordrb
  class User
    attr_accessor :steam_uid

    def esm_user
      @esm_user ||= lambda do
        user = ESM::User.find_by_discord_id(self.id.to_s) || ESM::User.new(discord_id: self.id.to_s)
        user.update(discord_username: self.username, discord_discriminator: self.discriminator)
        user
      end.call
    end
  end
end
