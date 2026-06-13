# frozen_string_literal: true

module Servers
  class TerritoriesController < AuthenticatedController
    def show
      render locals: {
        current_server:,
        current_territory:
      }
    end

    def pay
      # The client mints idempotency_key per form render, so a double-click
      # dedupes to the same row and the payment fires once.
      command = ESM::ServerCommand.find_or_create_by(
        user_id: current_user.id,
        idempotency_key: params.require(:idempotency_key)
      ) do |new_command|
        new_command.server = current_server
        new_command.command_name = "territory_pay"
        new_command.arguments = {territory_id: params.require(:territory_territory_id)}
      end

      # A non-pending row means this one was already dispatched (a re-click on a
      # stale button); skip re-firing and just render its current state.
      if command.pending?
        ESM::Service::API.call(:territory_pay, command_id: command.id)

        # Give a quick payment a moment to land so it resolves in this response
        # rather than flashing a spinner the client poller clears a beat later.
        Poll.until(timeout: 1.second, every: 0.1.seconds) { command.reload.settled? }
      end

      render locals: {command:, dom_id: params.require(:dom_id)}
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end

    def current_territory
      # The result is scoped to this player's territory rights, so the cache key must
      # include their steam_uid. A shared key would let an owner's cached payload be
      # served to a user who has no access to the territory.
      territory_data =
        ESM.cache.fetch(
          "territory_#{current_server.id}_#{params[:territory_id]}_#{current_user.steam_uid}", expires_in: 5.seconds
        ) do
          current_server.territory_info(params[:territory_id], steam_uid: current_user.steam_uid)
        end

      return if territory_data.blank?

      ESM::Exile::Territory.new(server: current_server, territory: territory_data)
    end
  end
end
