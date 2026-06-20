# frozen_string_literal: true

# Loads the current player's on-server snapshot (locker, pocket, stats, their
# territories), cached briefly so the reads around one interaction don't each
# hit the extension. Mirrors TerritoryLoading; kept separate because a player
# and a territory are distinct lookups against the game server.
module PlayerLoading
  extend ActiveSupport::Concern

  private

  def load_player(server, steam_uid, force: false)
    key = "player_#{server.id}_#{steam_uid}"
    ESM.cache.delete(key) if force

    data =
      ESM.cache.fetch(key, expires_in: 5.seconds) do
        server.player_info(steam_uid)
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        # The bot or the game server is unreachable. Degrade to "no data" (the
        # page shows an offline empty state) rather than a 500, and cache the nil
        # briefly so a down server isn't hammered on every refresh.
        Rails.logger.warn("[load_player] player_info unavailable: #{e.message}")
        nil
      end

    # No character on this server yet (never spawned in, or server offline)
    return if data.blank?

    ESM::Exile::Player.new(server:, player: data)
  end

  # The fresh player snapshot to fold into a settled command's /me refresh. Pay
  # and upgrade both draw from the locker, so a completed command leaves the
  # page's poptab totals (and the territory cards' due state) stale. Forces a
  # fresh fetch; a failure returns nil so the page is left untouched.
  def refreshed_player(command)
    return unless command.completed?

    load_player(command.server, current_user.steam_uid, force: true)
  end
end
