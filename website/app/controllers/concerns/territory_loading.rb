# frozen_string_literal: true

# Loads a player-scoped territory snapshot, cached briefly so the repeated reads
# around one interaction (open the modal, poll, refresh) don't each hit the
# extension. The cache key includes the steam_uid because the payload is scoped
# to that player's rights; a shared key could serve an owner's view to someone
# with no access to the territory.
module TerritoryLoading
  extend ActiveSupport::Concern

  private

  def load_territory(server, territory_id, steam_uid, force: false)
    key = "territory_#{server.id}_#{territory_id}_#{steam_uid}"
    ESM.cache.delete(key) if force

    territory_data =
      ESM.cache.fetch(key, expires_in: 5.seconds) do
        server.territory_info(territory_id, steam_uid:)
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

    load_territory(command.server, command.arguments[:territory_id], current_user.steam_uid, force: true)
  end
end
