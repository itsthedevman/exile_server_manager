# frozen_string_literal: true

module Communities
  class BroadcastsController < RegisteredController
    include Commands

    def create
      return unless check_for_command_access("broadcast")

      command = call_async_command(
        "broadcast",
        arguments: {message: params.require(:message), broadcast_to:}
      )

      render locals: {command:, result: result_for(command)}
    end

    def status
      command = ESM::ServiceCommand.find_by(public_id: params.require(:command_id), user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {command:, result: result_for(command)}
    end

    private

    # The audience selector posts either the "all" keyword or one of the community's server public ids. A public id is
    # translated here rather than posted as a server_id so a malformed or foreign value can't reach the command as a
    # server it would go looking for.
    def broadcast_to
      target = params[:broadcast_to].to_s
      return "all" if target == "all"

      server = current_community.servers.find_by(public_id: target)
      not_found! if server.nil?

      server.server_id
    end

    # What the result partial renders: how many people were messaged, the player-facing reason it didn't happen, or
    # nil while the command is still in flight.
    def result_for(command)
      return unless command.settled?
      return {error: command.error_message, recipients: nil}.to_datum if command.error_message.present?

      {error: nil, recipients: command.result[:recipients]}.to_datum
    end

    # Overrides Commands#render_command_denied so a denial lands in the modal's own result frame.
    def render_command_denied(message)
      respond_to do |format|
        format.html { not_found! }

        format.turbo_stream do
          render(
            turbo_stream: turbo_stream.replace(
              "broadcast_result",
              partial: "communities/broadcasts/rejection",
              locals: {message:}
            ),
            status: :unprocessable_content
          )
        end
      end
    end

    # Overrides Commands#command_denied_message with broadcast-specific wording.
    def command_denied_message(reason)
      case reason
      when :unregistered
        "Link your Steam account on your account page before you can broadcast."
      when :disabled
        "Broadcasting is not enabled on #{current_community.community_id}."
      when :not_allowlisted
        "You do not have permission to broadcast on #{current_community.community_id}."
      else
        "You can't broadcast right now."
      end
    end
  end
end
