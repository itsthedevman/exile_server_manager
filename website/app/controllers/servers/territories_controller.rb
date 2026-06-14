# frozen_string_literal: true

module Servers
  class TerritoriesController < AuthenticatedController
    include TerritoryLoading
    include PlayerLoading

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

      render locals: {
        command:,
        dom_id: params.require(:dom_id),
        current_server:,
        refreshed_territory: refreshed_territory(command),
        refreshed_player: refreshed_player(command)
      }
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end

    def current_territory
      load_territory(current_server, params[:territory_id], current_user.steam_uid)
    end
  end
end
