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
      end

    # No character on this server yet (never spawned in, or server offline)
    return if data.blank?

    territories =
      (data[:territories] || []).map { |territory| ESM::Exile::Territory.new(server:, territory:) }

    # Split into two display groups so a card row never stretches to match a
    # neighbor's pay panel: due-soon ordered by urgency (overdue leads), the rest
    # alphabetically.
    due, upcoming = territories.partition(&:payment_due_soon?)
    data[:territories] = territories
    data[:due_territories] = due.sort_by { |t| [t.days_left_until_payment_due, t.name.to_s.downcase] }
    data[:upcoming_territories] = upcoming.sort_by { |t| t.name.to_s.downcase }

    data.to_istruct
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
