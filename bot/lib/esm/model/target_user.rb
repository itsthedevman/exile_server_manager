# frozen_string_literal: true

module ESM
  class TargetUser
    class ESMUser
      attr_reader :steam_uid

      def initialize(steam_uid)
        @steam_uid = steam_uid
      end

      def registered?
        true
      end

      def id
        @steam_uid
      end

      def steam_data
        @steam_data ||= lambda do
          player_data = ESM::Service::Steam.new(@steam_uid)

          OpenStruct.new(
            username: player_data.username,
            avatar: player_data.avatar,
            profile_url: player_data.profile_url,
            profile_visibility: player_data.profile_visibility,
            profile_created_at: player_data.profile_created_at,
            community_banned: player_data.community_banned?,
            vac_banned: player_data.vac_banned?,
            number_of_vac_bans: player_data.number_of_vac_bans,
            days_since_last_ban: player_data.days_since_last_ban
          )
        end.call
      end
    end

    attr_reader :steam_uid, :esm_user

    def initialize(steam_uid)
      @steam_uid = steam_uid
      @esm_user = ESMUser.new(steam_uid)
    end

    alias mention steam_uid
    alias distinct steam_uid
    alias username steam_uid
  end
end
