# frozen_string_literal: true

class ServersController < AuthenticatedController
  include Commands
  include ServerVersion

  COMMAND_CARDS = %w[me gamble reward]

  # Not all cards - info is the player lookup bar. What these share is that each one puts something in the Admin
  # tools section, so any of them is reason enough to render the section at all.
  ADMIN_TOOLS = %w[info sqf]

  def show
    not_found! if current_server.nil?

    cards_available = COMMAND_CARDS.any? { |c| command_accessible?(c) }
    admin_tools_available = ADMIN_TOOLS.any? { |c| command_accessible?(c) }

    render locals: {current_server:, cards_available:, admin_tools_available:}
  end

  # What Steam knows about the server right now: its map, how many are on, and the game version. Loaded lazily into
  # the sidebar frame because it's a UDP round trip to the owner's own box, so a firewalled or dead server costs this
  # request the timeout instead of costing every page in the hub.
  def live
    not_found! if current_server.nil?

    render partial: "servers/live", locals: {current_server:, info: server_query_info}
  end

  private

  def current_server
    @current_server ||= ESM::Server.includes(community: :command_configurations).find_by_public_id(params[:id])
  end

  # Cached per server rather than per viewer, since the answer is the same for everyone looking. The window is longer
  # than the game-server reads elsewhere in the hub: nothing here changes second to second, and every miss costs a
  # round trip to a box ESM doesn't own. A failure caches too, so a server that's down isn't retried on every frame.
  def server_query_info
    ESM.cache.fetch("server_query_#{current_server.id}", expires_in: 1.minute) do
      ESM::Steam::ServerQuery.info(host: current_server.server_ip, port: current_server.query_port)
    rescue ESM::Steam::ServerQuery::Error => e
      Rails.logger.warn("[servers#live] query failed for #{current_server.server_id}: #{e.message}")
      nil
    end
  end
end
