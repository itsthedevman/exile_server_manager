# frozen_string_literal: true

module ESM
  class Message
    class Player < ImmutableStruct.define(:discord_id, :discord_name, :discord_mention, :steam_uid)
      def self.from(user)
        # Creates a hash with the keys being the keys of this class, and the value of nil
        # Allows for defaulting the values since ImmutableStruct requires a value of some sort
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
          data[:steam_uid] = user.steam_uid
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
