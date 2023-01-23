# frozen_string_literal: true

module Discordrb
  class User
    attr_accessor :steam_uid
    attr_writer :esm_user

    def esm_user
      @esm_user ||= lambda do
        user = ESM::User.find_by_discord_id(id.to_s) || ESM::User.new(discord_id: id.to_s)
        user.update(discord_username: username, discord_discriminator: discriminator)
        user
      end.call
    end

    def to_h
      {
        id: id.to_s,
        username: username,
        discriminator: discriminator,
        avatar_url: avatar_url
      }
    end
  end
end
