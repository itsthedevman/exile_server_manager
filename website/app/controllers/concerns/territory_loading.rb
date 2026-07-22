# frozen_string_literal: true

# Loads a player-scoped territory snapshot, cached briefly so the repeated reads
# around one interaction (open the modal, poll, refresh) don't each hit the
# extension. The cache key includes the steam_uid because the payload is scoped
# to that player's rights; a shared key could serve an owner's view to someone
# with no access to the territory.
#
# Requires the Commands concern
#
module TerritoryLoading
  extend ActiveSupport::Concern

  private

  def load_territory(server, territory_id, steam_uid, force: false)
    key = "territory_#{server.id}_#{territory_id}_#{steam_uid}"
    ESM.cache.delete(key) if force

    territory_data =
      ESM.cache.fetch(key, expires_in: 5.seconds) do
        call_sync_command("territory", arguments: {territory_id:})
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        # The bot or the game server is unreachable. Degrade to "no data" (the
        # modal shows its unavailable state) rather than a 500.
        Rails.logger.warn("[load_territory] territory_info unavailable: #{e.message}")
        nil
      end

    return if territory_data.blank?

    ESM::Exile::Territory.new(server:, territory: territory_data)
  end

  # The fresh territory to fold into a settled command's modal refresh. Only a
  # completed command warrants it; a failure keeps the modal as-is so its
  # in-place error trace survives. Forces a fresh fetch so the new payment dates
  # land instead of the snapshot cached when the modal opened.
  def refreshed_territory(command)
    return unless command.completed?

    # A successful set_id renames the territory, so it now answers only to the new id; reload by that.
    # Every other command leaves the id untouched and falls back to it.
    territory_id = command.arguments[:new_territory_id].presence || command.arguments[:territory_id]

    load_territory(command.server, territory_id, current_user.steam_uid, force: true)
  end

  # The territory snapshot used to rebuild the retry button after a failed
  # payment, so it carries the same price and urgency tone as the original
  # rather than re-rendering as a priceless, success-green control. Only a
  # settled-but-unsuccessful command needs it; success and pending return nil so
  # the common path never pays for the lookup.
  def retry_territory(command)
    return unless command.settled?
    return if command.completed?

    load_territory(command.server, command.arguments[:territory_id], current_user.steam_uid)
  end
end
