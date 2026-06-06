# frozen_string_literal: true

module ESM
  class Message
    # Data.define returns a fresh class on every load, so subclassing it inline trips a superclass mismatch when
    # this file is reloaded. Pin it to a guarded constant so a reload reopens Player against the same superclass.
    PlayerData = ::Data.define(:discord_id, :discord_name, :discord_mention, :steam_uid) unless defined?(PlayerData)

    class Player < PlayerData
      def self.from(user)
        # Creates a hash with the keys being the keys of this class, and the value of nil
        # Allows for defaulting the values since Data requires a value of some sort
        data = members.zip([nil]).to_h

        case user
        when ESM::User
          data.merge!(
            steam_uid: user.steam_uid,
            discord_id: user.discord_id,
            discord_name: user.discord_username,
            discord_mention: user.mention
          )
        when ESM::User::Ephemeral
          # Having steam_uid as the default saves work for the A3 server
          data[:steam_uid] = user.steam_uid
          data[:discord_mention] = user.mention
          data[:discord_name] = user.mention
        else
          data.merge!(user)
        end

        new(**data)
      end

      def to_h
        super.delete_if { |_k, v| v.nil? }
      end
    end
  end
end
