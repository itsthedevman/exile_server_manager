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

  included do
    # Whether a settled command's overview belongs to the viewer. False on the admin player show page, where the session
    # marks a viewed player, so the refresh renders that player (their linked avatar, no self-service actions) rather
    # than the viewer. Read alongside refreshed_player so the reloaded player and the chrome around it always agree.
    def viewing_self?
      session[:viewing_player_uid].blank?
    end

    helper_method :viewing_self?
  end

  private

  # The viewer's own on-server snapshot, read through me. It carries the read time alongside the payload so /me's
  # freshness stamp reports the read rather than the render: the entry outlives the request, so a render that timed
  # itself would call every cache hit current. Keyed on server and viewer, since the command reads as the current user
  # against the current server and keying it any other way would file one player's payload under another's. The nil
  # caches too, so a down server isn't hammered on every refresh.
  def current_player_snapshot(force: false)
    key = current_player_cache_key
    ESM.cache.delete(key) if force

    ESM.cache.fetch(key, expires_in: 5.seconds) do
      data = call_sync_command("me")

      data.blank? ? nil : {fetched_at: Time.current, data:}
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      # The bot or the game server is unreachable. Degrade to "no data" (the page shows an offline empty state)
      # rather than a 500.
      Rails.logger.warn("[current_player_snapshot] player unavailable: #{e.message}")
      nil
    end
  end

  def load_player(force: false)
    player_from(current_player_snapshot(force:))
  end

  # A snapshot's payload as a player, or nothing when there's no snapshot to build from - an absent player (never
  # spawned in), an unknown uid, or a server that couldn't be reached.
  def player_from(snapshot)
    return if snapshot.blank?

    ESM::Exile::Player.new(server: current_server, player: snapshot[:data])
  end

  # One target player's on-server snapshot, read as the current user through the info command (the admin path) rather
  # than me. It carries the read time alongside the payload so the show page's freshness stamp reports the read rather
  # than the render. Cached briefly and keyed on server and target, so several admins opening the same player share one
  # read and a settle refresh reuses the entry the show page warmed. The nil caches too, so a down server or an unknown
  # uid isn't retried on every reload.
  def target_player_snapshot(uid, force: false)
    key = target_player_cache_key(uid)
    ESM.cache.delete(key) if force

    ESM.cache.fetch(key, expires_in: 5.seconds) do
      data = call_sync_command("info", arguments: {target: uid})

      data.blank? ? nil : {fetched_at: Time.current, data:}
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      Rails.logger.warn("[target_player_snapshot] player info unavailable: #{e.message}")
      nil
    end
  end

  # The fresh player to fold into a settled command's overview refresh. Pay and upgrade both draw from the locker, and a
  # rename changes a territory's id, so a completed command leaves the overview's poptab totals and its territory cards'
  # ids stale. Which player it reloads follows the session: the admin show page marks the viewed player, so the refresh
  # reads that player through info rather than the viewer's own me snapshot; /me clears the marker and reloads the
  # viewer. A failure returns nil so the overview is left untouched.
  def refreshed_player(command)
    return unless command.completed?

    # A reset-all wipes every player, so there's no single overview to reload - skip the read entirely.
    return if command.command_name == "reset" && command.arguments[:target].blank?

    viewed_uid = session[:viewing_player_uid]
    return load_player(force: true) if viewed_uid.blank?

    player_from(target_player_snapshot(viewed_uid, force: true))
  end

  def current_player_cache_key
    # The command reads as the current user against the current server, so the key is built from the same pair.
    # Keying it any other way would file one player's payload under another's.
    #
    # The entry is a stamped snapshot rather than a bare payload, and the cache outlives a deploy, so the key carries
    # the shape. Reading a pre-stamp entry back would hand the page a player with every field missing.
    "player_snapshot_#{current_server.id}_#{current_user.steam_uid}"
  end

  # Keyed on server and target uid, matching the admin info read. Shared so target_player_snapshot and a reset that
  # drops the read after wiping the player key it identically.
  def target_player_cache_key(uid)
    "player_info_#{current_server.id}_#{uid}"
  end
end
