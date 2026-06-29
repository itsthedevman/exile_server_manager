# frozen_string_literal: true

module Servers
  # Toggles a server in the current user's favorites. Each action renders its
  # turbo_stream template, which swaps just the toggle button so the page
  # (Discover, the dashboard, the server hub) updates in place.
  class FavoritesController < AuthenticatedController
    def create
      return not_found! if current_server.nil?

      current_user.server_favorites.find_or_create_by(server: current_server)

      render locals: {current_server:}
    end

    def destroy
      return not_found! if current_server.nil?

      current_user.server_favorites.find_by(server: current_server)&.destroy

      render locals: {current_server:}
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end
  end
end
