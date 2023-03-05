# frozen_string_literal: true

module ESM
  class TargetUser
    attr_reader :steam_uid, :esm_user

    def initialize(steam_uid)
      @steam_uid = steam_uid
      @esm_user = ESMUser.new(steam_uid)
    end

    alias_method :id, :steam_uid
    alias_method :mention, :steam_uid
    alias_method :distinct, :steam_uid
    alias_method :username, :steam_uid

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
  end
end
