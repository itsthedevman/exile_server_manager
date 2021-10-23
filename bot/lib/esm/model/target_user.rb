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
        @steam_data ||= ESM::SteamAccount.new(@steam_uid)
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
