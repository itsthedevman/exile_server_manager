# frozen_string_literal: true

module Servers
  class SqfController < RegisteredController
    include Commands
    include ServerVersion

    before_action :require_supported_server!

    def create
      return unless check_for_command_access("sqf")

      command = call_async_command(
        "sqf",
        arguments: {code_to_execute: params.require(:code_to_execute), target: sqf_target}
      )

      render locals: {command:, result: result_for(command)}
    end

    def status
      command = ESM::ServiceCommand.find_by(public_id: params.require(:command_id), user_id: current_user.id)
      return head :not_found if command.nil?

      render locals: {command:, result: result_for(command)}
    end

    private

    def current_server
      @current_server ||= ESM::Server.includes(community: :command_configurations)
        .find_by_public_id(params.require(:server_id))
    end

    # The target selector posts either a scope keyword (server/all) or a player's steam uid. Anything that isn't a
    # recognized scope is treated as a player uid; the command's own argument check has the final say on validity.
    def sqf_target
      target = params[:target].to_s
      return "server" if target.blank?

      target
    end

    # The SQF return value the result partial renders: the executed payload on success, the player-facing error on
    # failure, or nil until the command settles. `returned_nothing` separates "ran and gave back a value" from "ran
    # and gave back nothing at all" - the extension nulls the type alongside the result in that case, and the two
    # are worth saying differently since a null return is the same shape whether the code was fine or nonsense.
    def result_for(command)
      return unless command.settled?
      return {error: command.error_message}.to_datum if command.error_message.present?

      Data.define(:error, :output, :returned_nothing).new(
        error: nil,
        output: command.result[:result],
        returned_nothing: command.result[:type].nil?
      )
    end

    # Overrides Commands#render_command_denied so a denial lands in this tool's own result frame.
    def render_command_denied(message)
      respond_to do |format|
        format.html { not_found! }

        format.turbo_stream do
          render(
            turbo_stream: turbo_stream.replace(
              "sqf_result",
              partial: "servers/sqf/rejection",
              locals: {message:}
            ),
            status: :unprocessable_content
          )
        end
      end
    end

    # Overrides Commands#command_denied_message with SQF-specific wording.
    def command_denied_message(reason)
      case reason
      when :unregistered
        "Link your Steam account on your account page before you can run SQF."
      when :disabled
        "The SQF tool is not enabled on #{current_server.server_id}."
      when :not_allowlisted
        "You do not have permission to run SQF on #{current_server.server_id}."
      when :server_offline
        "#{current_server.server_id} is offline. SQF can't run right now."
      else
        "You can't run SQF right now."
      end
    end
  end
end
