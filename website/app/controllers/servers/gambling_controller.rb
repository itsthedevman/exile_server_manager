# frozen_string_literal: true

module Servers
  class GamblingController < RegisteredController
    def create
      access = ESM::CommandAccess.new(command_name: "gamble", user: current_user, server: current_server)

      verdict = access.verdict
      return render_rejection(gamble_denial_message(verdict.reason)) if verdict.denied?

      command = ESM::ServerCommand.find_or_create_by(
        user_id: current_user.id,
        idempotency_key: params.require(:idempotency_key)
      ) do |new_command|
        new_command.server = current_server
        new_command.command_name = "gamble"
        new_command.arguments = {amount: params.require(:amount)}
      end

      # Only the request that actually created the row dispatches, so a same-key retry dedupes to it instead of firing a
      # second bet. The cooldown is claimed atomically here, before dispatch, so two rapid bets can't both get through:
      # the loser's claim fails and its orphan row is dropped, freeing the held key to retry once the window passes.
      if command.previously_new_record?
        if !access.claim_cooldown!
          command.destroy!
          render_rejection(gamble_cooldown_message)
          return
        end

        ESM::Service::API.call(:server_gamble, command_id: command.id)
      end

      Poll.until(timeout: 1.second, every: 0.1.seconds) { command.reload.settled? } if command.pending?

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

    # Renders a denial into the result slot as a 422 so Turbo shows the message without rotating the form's idempotency
    # key - a rejected attempt keeps its key, so retrying can't slip past the dedupe or the cooldown claim.
    def render_rejection(message)
      render(
        turbo_stream: turbo_stream.replace(
          "gamble_result",
          partial: "servers/gambling/rejection",
          locals: {message:}
        ),
        status: :unprocessable_entity
      )
    end

    # Web-facing copy for a permission denial. Short by design - the server hub shows it inline on the card, not as a
    # Discord embed. :unregistered is a backstop; the hub already redirects unregistered players to register.
    def gamble_denial_message(reason)
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

    def gamble_cooldown_message
      "Slow down! Give your last bet a moment to settle before gambling again."
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
