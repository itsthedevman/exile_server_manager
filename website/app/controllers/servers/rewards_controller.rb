# frozen_string_literal: true

module Servers
  class RewardsController < RegisteredController
    include Commands
    include ServerVersion

    before_action :require_supported_server!

    ##
    # Redeeming a package and finishing a waiting claim are the same request. Which one it is depends on what the
    # player already has, and the command works that out for itself, so the page does not have to guess.
    #
    def create
      return unless check_for_command_access("reward")

      command = call_async_command("reward", arguments: command_arguments)

      render locals: {current_server:, command:}
    end

    def status
      command = ESM::ServiceCommand.find_by(public_id: params.require(:command_id), user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {current_server:, command:}
    end

    ##
    # The garages a vehicle can be parked in. A round trip to the game server, so the picker loads it after the page
    # rather than making every dashboard wait on it.
    #
    def territories
      render partial: "servers/rewards/territory_select", locals: {
        current_server:,
        index: params.require(:index),
        territories: player_territories
      }
    end

    private

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations)
        .find_by_public_id(params.require(:server_id))
    end

    def command_arguments
      arguments = {}
      arguments[:reward_id] = params[:reward_id] if params[:reward_id].present?

      vehicles = vehicle_choices
      arguments[:vehicles] = vehicles if vehicles.present?

      arguments
    end

    ##
    # What the player decided about each vehicle, in the claim's own order.
    #
    # The form indexes its fields so the choices cannot be reordered on the way in; the command pairs them with the
    # claim positionally and refuses the whole thing if the counts disagree.
    #
    # @return [Array<Hash>]
    #
    def vehicle_choices
      choices = params[:vehicles]
      return [] if choices.blank?

      choices.to_unsafe_h
        .sort_by { |index, _choice| index.to_i }
        .map { |_index, choice| choice.slice("spawn_location", "territory_id", "pin_code") }
    end

    ##
    # Territories this player can store a vehicle in, or an empty list when the server cannot answer.
    #
    # A picker that cannot be filled is not a reason to fail the page: the player can still take a vehicle that
    # spawns next to them, and the empty state says why.
    #
    # @return [Array]
    #
    def player_territories
      call_sync_command("territories") || []
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      Rails.logger.warn("[rewards#territories] #{current_server.server_id}: #{e.message}")
      []
    end

    # Overrides Commands#render_command_denied. The panel is the one thing this controller ever replaces, so a denial
    # lands in it the same way an outcome does rather than needing the client to name a target.
    def render_command_denied(message)
      respond_to do |format|
        format.html { not_found! }

        format.turbo_stream do
          render(
            turbo_stream: turbo_stream.replace(
              "reward_panel",
              partial: "servers/rewards/denied",
              locals: {current_server:, message:}
            ),
            status: :unprocessable_content
          )
        end
      end
    end

    # Overrides Commands#command_denied_message
    def command_denied_message(reason)
      case reason
      when :unregistered
        "Link your Steam account on your account page before you can claim rewards."
      when :disabled
        "Rewards are not enabled on #{current_server.server_id}."
      when :not_allowlisted
        "You do not have permission to claim rewards on #{current_server.server_id}."
      when :server_offline
        "#{current_server.server_id} is offline. Rewards are delivered in game, so this has to wait until it is back."
      else
        "You can't claim a reward right now."
      end
    end
  end
end
