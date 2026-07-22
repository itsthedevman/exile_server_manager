# frozen_string_literal: true

# Loads the current player's on-server snapshot (locker, pocket, stats, their
# territories), cached briefly so the reads around one interaction don't each
# hit the extension. Mirrors TerritoryLoading; kept separate because a player
# and a territory are distinct lookups against the game server.
#
# Requires the Commands concern
#
module PlayerLoading
  extend ActiveSupport::Concern

  private

  def load_player(force: false)
    # The command reads as the current user against the current server, so the key is built from the same pair.
    # Keying it any other way would file one player's payload under another's.
    key = "player_#{current_server.id}_#{current_user.steam_uid}"
    ESM.cache.delete(key) if force

    data =
      ESM.cache.fetch(key, expires_in: 5.seconds) do
        call_sync_command("me")
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        # The bot or the game server is unreachable. Degrade to "no data" (the
        # page shows an offline empty state) rather than a 500, and cache the nil
        # briefly so a down server isn't hammered on every refresh.
        Rails.logger.warn("[load_player] player unavailable: #{e.message}")
        nil
      end

    # No character on this server yet (never spawned in, or server offline)
    return if data.blank?

    ESM::Exile::Player.new(server: current_server, player: data)
  end

  # The fresh player snapshot to fold into a settled command's /me refresh. Pay
  # and upgrade both draw from the locker, so a completed command leaves the
  # page's poptab totals (and the territory cards' due state) stale. Forces a
  # fresh fetch; a failure returns nil so the page is left untouched.
  def refreshed_player(command)
    return unless command.completed?

    load_player(force: true)
  end
end
