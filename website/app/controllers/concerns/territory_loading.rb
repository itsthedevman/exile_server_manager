# frozen_string_literal: true

# Loads a territory snapshot, cached briefly so the repeated reads around one interaction (open the modal, poll,
# refresh) don't each hit the extension. Which command backs the read - and how the cache is keyed - follows the
# viewer's access basis: an admin reads any territory through info and shares one entry per territory, since their
# access doesn't vary; everyone else reads only their own through the territory command under a per-user key. That
# per-user key is load-bearing, not just dedup: the cache miss is what runs the membership check, so a shared key would
# let a non-member ride a member's warm entry and see a territory they have no rights to.
#
# Requires the Commands concern
#
module TerritoryLoading
  extend ActiveSupport::Concern

  included do
    def territory_admin?
      current_server.community.territory_admin?(current_user)
    end

    helper_method :territory_admin?
  end

  private

  def load_territory(territory_id, force: false)
    admin = command_accessible?("info")

    key = territory_cache_key(territory_id, admin:)
    ESM.cache.delete(key) if force

    territory_data =
      ESM.cache.fetch(key, expires_in: 5.seconds) do
        call_sync_command(admin ? "info" : "territory", arguments: {territory_id:})
      rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
        # The bot or the game server is unreachable. Degrade to "no data" (the
        # modal shows its unavailable state) rather than a 500.
        Rails.logger.warn("[load_territory] territory unavailable: #{e.message}")
        nil
      end

    return if territory_data.blank?

    ESM::Exile::Territory.new(server: current_server, territory: territory_data)
  end

  # An admin's view of a territory is identical to every other admin's, so they share one entry; a member's read is
  # keyed to them because the miss is what enforces their membership. Keep the admin and non-admin key spaces disjoint
  # so a non-admin can never resolve to the shared entry an admin warmed.
  def territory_cache_key(territory_id, admin:)
    base = "territory_#{current_server.id}_#{territory_id}"
    admin ? base : "#{base}_#{current_user.steam_uid}"
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

    load_territory(territory_id, force: true)
  end

  # The territory snapshot used to rebuild the retry button after a failed
  # payment, so it carries the same price and urgency tone as the original
  # rather than re-rendering as a priceless, success-green control. Only a
  # settled-but-unsuccessful command needs it; success and pending return nil so
  # the common path never pays for the lookup.
  def retry_territory(command)
    return unless command.settled?
    return if command.completed?

    load_territory(command.arguments[:territory_id])
  end
end
