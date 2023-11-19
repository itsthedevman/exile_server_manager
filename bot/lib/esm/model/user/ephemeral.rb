# frozen_string_literal: true

module ESM
  class User
    class Ephemeral
      attr_reader :steam_uid, :discord_user

      delegate :mention, :distinct, :username, to: :@discord_user

      def initialize(id)
        @steam_uid = id
        @discord_user = DiscordUser.new(id)
      end

      def registered?
        false
      end

      def id
        steam_uid
      end

      def steam_data
        @steam_data ||= ESM::SteamAccount.new(steam_uid)
      end

      def valid?
        false
      end

      def attributes
        {
          id: id,
          ephemeral: true
        }
      end

      class DiscordUser
        attr_reader :steam_uid

        def initialize(id)
          @steam_uid = id
        end

        alias_method :id, :steam_uid
        alias_method :mention, :steam_uid
        alias_method :distinct, :steam_uid
        alias_method :username, :steam_uid
      end
    end
  end
end
