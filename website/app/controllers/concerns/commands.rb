# frozen_string_literal: true

module Commands
  extend ActiveSupport::Concern

  included do
    helper_method :command_accessible?
  end

  private

  ##
  # Builds a CommandAccess check for command_name against the current user and server, returning its permission verdict.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [ESM::Command::Permission::Result] The verdict, exposing allowed? and the denial reason when not allowed
  #
  def command_verdict(command_name)
    ESM::CommandAccess.new(
      command_name:,
      user: current_user,
      server: current_server
    ).verdict
  end

  ##
  # Whether the current user is allowed to run command_name against the current server.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [Boolean] true when the verdict allows the command
  #
  def command_accessible?(command_name)
    command_verdict(command_name).allowed?
  end

  ##
  # Runs the CommandAccess verdict for command_name against the current user and server. On a denial, renders the
  # player-facing reason into the command's result slot and returns false so the caller can bail.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [Boolean] true if allowed, false if denied
  #
  def check_for_command_access(command_name)
    verdict = command_verdict(command_name)
    return true if verdict.allowed?

    render_command_denied(command_denied_message(verdict.reason))

    false
  end

  ##
  # Creates (or reuses) the ServerCommand for command_name and, when it is freshly pending, dispatches it to the service
  # API and briefly polls for it to settle before returning.
  #
  # @param command_name [String, Symbol] The name of the command
  # @param arguments [Hash] Extra command arguments merged into the server/community context
  #
  # @return [ESM::ServerCommand] The command, settled if it resolved within the poll window, else still pending
  #
  def call_service_command(command_name, arguments: {})
    command = create_command_for(command_name, arguments:)

    # Only the request that created the row dispatches, so a same-key retry (double-click, Turbo replay) dedupes to the
    # existing command instead of firing the work a second time.
    ESM::Service::API.call(:server_command, command_id: command.id) if command.previously_new_record?

    # Give a quick command a moment to land so it resolves in this response rather than flashing a spinner the client
    # poller clears a beat later. An already-settled row skips the wait; a retry rides the in-flight command's result.
    Poll.until(timeout: 1.second, every: 0.1.seconds) { command.reload.settled? } if command.pending?

    command
  end

  ##
  # Finds or creates the current user's ServerCommand for this request, keyed on the request's idempotency key so a
  # retried request returns the same command rather than a duplicate. A newly built record is seeded with the current
  # server, command name, and the server/community context merged with arguments.
  #
  # @param command_name [String, Symbol] The name of the command
  # @param arguments [Hash] Extra command arguments merged into the base server/community context
  #
  # @return [ESM::ServerCommand] The found or newly created command
  #
  # @raise [ActionController::ParameterMissing] When the request omits :idempotency_key
  #
  def create_command_for(command_name, arguments: {})
    ESM::ServerCommand.find_or_create_by(
      user_id: current_user.id,
      idempotency_key: params.require(:idempotency_key)
    ) do |new_command|
      new_command.server = current_server
      new_command.command_name = command_name

      new_command.arguments = {
        server_id: current_server.server_id,
        community_id: current_server.community.community_id
      }.merge(arguments)
    end
  end

  ##
  # Player-facing copy for a permission denial, keyed on the verdict reason. Generic by design; a controller can
  # override for command-specific wording (see GamblingController).
  #
  # @param reason [Symbol, nil] The verdict's denial reason
  #
  # @return [String] The message to show the player
  #
  def command_denied_message(reason)
    server = current_server.server_name

    case reason
    when :unregistered
      "Link your Steam account on your account page first."
    when :disabled
      "This command isn't enabled on #{server}."
    when :not_allowlisted
      "You don't have permission to run this command on #{server}."
    when :server_offline
      "#{server} is offline. Try again once it's back up."
    else
      "You can't run that command right now."
    end
  end

  ##
  # Renders a denial into the dom_id the client mints for the command's result slot. HTML requests get a 404;
  # turbo_stream requests replace the target frame with the shared denial partial. GamblingController overrides this
  # for its own fixed result frame.
  #
  # @param message [String] The player-facing denial copy to render
  #
  # @return [void]
  #
  # @raise [ActionController::ParameterMissing] When a turbo_stream request omits :dom_id
  #
  def render_command_denied(message)
    respond_to do |format|
      format.html { not_found! }

      format.turbo_stream do
        target = params.require(:dom_id)

        render(
          turbo_stream: turbo_stream.replace(target, partial: "shared/command_denied", locals: {target:, message:}),
          status: :unprocessable_content
        )
      end
    end
  end
end
