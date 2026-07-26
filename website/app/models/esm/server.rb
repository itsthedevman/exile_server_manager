# frozen_string_literal: true

module ESM
  class Server < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    public_attributes(
      :server_id, :server_name,
      id: ->(server) { server.public_id }
    )

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    # =============================================================================
    # SCOPES
    # =============================================================================

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def recently_created?(time: 30.seconds.ago)
      created_at.between?(time, Time.current)
    end

    def connected?
      Rails.cache.fetch("server:#{id}:connected", expires_in: 10.seconds) do
        ESM::Service::API.call(:servers_connected, id:, idempotent: true)
      rescue ESM::Service::API::Unreachable
        # Bot/NATS not answering: degrade to "not connected" rather than 500ing
        # the page. Cached for the same window so we don't hammer a dead bot.
        false
      end
    end

    def ui_v2?
      @ui_v2 ||= Semantic::Version.new(ui_version || "2.0.0") >= Semantic::Version.new("2.0.0")
    end

    #
    # Disconnects this server using its previous ID after a community renamed
    # itself. The Arma DLL reconnects automatically against the new ID.
    #
    def reconnect(old_id)
      ESM::Service::API.call(:servers_reconnect, id:, old_id:)
    end

    #
    # Pushes a fresh init package to a connected server so settings changes take
    # effect without a full disconnect.
    #
    def reinitialize
      ESM::Service::API.call(:servers_update, id:)
    end
  end
end
