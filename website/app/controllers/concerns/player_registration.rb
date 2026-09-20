# frozen_string_literal: true

##
# Answers whether the current server has ever seen the current player, which is what everything built on their
# character depends on.
#
# A database read rather than a command, because every feature on the page belongs to a command a community can switch
# off and this question has to be answerable whatever they have enabled.
#
module PlayerRegistration
  extend ActiveSupport::Concern

  # Long enough that reloading a page cannot ask the game server again and again, short enough that someone who just
  # joined is not told otherwise for long. The answer only changes once per player, on their first connect.
  ACCOUNT_CACHE_TTL = 5.seconds

  included do
    helper_method :player_joined_server?
  end

  private

  ##
  # Whether the current player has ever connected to the current server.
  #
  # An unreachable server answers true. The page behind this already has its own offline state, and the alternative is
  # telling a player who has played there for months to go and join.
  #
  # @return [Boolean]
  #
  def player_joined_server?
    return false if current_user.steam_uid.blank?

    key = "account_exists/#{current_server.id}/#{current_user.steam_uid}"

    # The negative caches with everything else. A player who has never joined is exactly who would otherwise reach the
    # game server on every reload.
    ESM.cache.fetch(key, expires_in: ACCOUNT_CACHE_TTL) do
      known = ESM::Service::API.call(
        :server_account_exists,
        server_id: current_server.id,
        steam_uid: current_user.steam_uid,
        idempotent: true
      )

      known.nil? || known
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      Rails.logger.warn("[player_joined_server?] #{current_server.server_id}: #{e.message}")
      true
    end
  end
end
