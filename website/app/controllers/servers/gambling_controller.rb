# frozen_string_literal: true

module Servers
  class GamblingController < AuthenticatedController
    def create
      command = ESM::ServerCommand.find_or_create_by(
        user_id: current_user.id,
        idempotency_key: params.require(:idempotency_key)
      ) do |new_command|
        new_command.server = current_server
        new_command.command_name = "server_gamble"
        new_command.arguments = {amount: params.require(:amount)}
      end

      if command.pending?
        ESM::Service::API.call(:server_gamble, command_id: command.id)

        Poll.until(timeout: 1.second, every: 0.1.seconds) { command.reload.settled? }
      end

      render locals: {command:, result: result_for(command), gamble_stat:}
    end

    def status
      command = ESM::ServerCommand.find_by(id: params.require(:command_id), user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {command:, result: result_for(command), gamble_stat:}
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params.require(:server_id))
    end

    def gamble_stat
      @gamble_stat ||= ESM::UserGambleStat.find_or_initialize_by(
        server_id: current_server.id,
        user_id: current_user.id
      )
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
