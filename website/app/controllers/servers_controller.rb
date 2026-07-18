# frozen_string_literal: true

class ServersController < AuthenticatedController
  include Commands

  COMMAND_CARDS = %w[me gamble]
  ADMIN_COMMAND_CARDS = %w[sqf]

  def show
    not_found! if current_server.nil?

    cards_available = COMMAND_CARDS.any? { |c| command_accessible?(c) }
    admin_cards_available = ADMIN_COMMAND_CARDS.any? { |c| command_accessible?(c) }

    render locals: {current_server:, cards_available:, admin_cards_available:}
  end

  private

  def current_server
    @current_server ||= ESM::Server.includes(community: :command_configurations).find_by_public_id(params[:id])
  end
end
