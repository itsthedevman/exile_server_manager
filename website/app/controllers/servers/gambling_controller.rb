# frozen_string_literal: true

module Servers
  class GamblingController < RegisteredController
    include Commands

    def create
      return unless check_for_command_access("gamble")

      command = call_service_command("gamble", arguments: {amount: params.require(:amount)})

      render locals: {command:, result: result_for(command), gamble_stat:}
    end

    def status
      command = ESM::ServiceCommand.find_by(public_id: params.require(:command_id), user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {command:, result: result_for(command), gamble_stat:}
    end

    private

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations)
        .find_by_public_id(params.require(:server_id))
    end

    def gamble_stat
      @gamble_stat ||= ESM::UserGambleStat.find_or_initialize_by(
        server_id: current_server.id,
        user_id: current_user.id
      )
    end

    # Overrides ServiceCommands#render_command_denied
    def render_command_denied(message)
      respond_to do |format|
        format.html { not_found! }

        format.turbo_stream do
          render(
            turbo_stream: turbo_stream.replace(
              "gamble_result",
              partial: "servers/gambling/rejection",
              locals: {message:}
            ),
            status: :unprocessable_content
          )
        end
      end
    end

    # Overrides ServiceCommands#command_denied_message
    def command_denied_message(reason)
      case reason
      when :unregistered
        "Link your Steam account on your account page before you can gamble."
      when :disabled
        "Gambling is not enabled on #{current_server.server_name}."
      when :not_allowlisted
        "You do not have permission to gamble on #{current_server.server_name}."
      when :server_offline
        "#{current_server.server_name} is offline. Betting is unavailable."
      else
        "You can't gamble right now."
      end
    end

    # The bet outcome the result partial renders: the win/loss payload on success,
    # the player-facing rejection text on failure, or nil until the command settles.
    # Streak comes from the freshly recorded stat, not the SQF payload.
    def result_for(command)
      return unless command.settled?
      return {error: command.error_message}.to_istruct if command.error_message.present?

      command.result
        .slice(:win, :amount, :locker_after)
        .merge(error: nil, streak: gamble_stat.current_streak)
        .to_istruct
    end
  end
end
