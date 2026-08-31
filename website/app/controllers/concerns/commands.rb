# frozen_string_literal: true

module Commands
  extend ActiveSupport::Concern

  include CommandGating

  private

  ##
  # Runs the CommandAccess verdict for command_name against the current user. On a denial, renders the
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
  # Runs command_name against the current server and blocks on its reply. Unlike {#call_async_command} nothing is
  # persisted: the page is holding this request open waiting for the value.
  #
  # @param command_name [String, Symbol] The name of the command
  # @param arguments [Hash] Extra command arguments merged into the server context
  #
  # @return [Object, nil] Whatever the command replied with, or nil when it had nothing to say
  #
  def call_sync_command(command_name, arguments: {})
    raise ArgumentError, "Unknown command: #{command_name}" if ESM::Command[command_name].nil?

    # A sync command is a read the page is blocking on, so a timeout is safe to retry - it can't double-run anything.
    ESM::Service::API.call(
      :sync_command,
      command_name:,
      user_id: current_user.id,
      community_id: current_server.community.id,
      arguments: arguments.merge(server_id: current_server.server_id),
      idempotent: true
    )
  end

  ##
  # Creates (or reuses) the ServiceCommand for command_name and, when it is freshly pending, dispatches it to the service
  # API and briefly polls for it to settle before returning.
  #
  # @param command_name [String, Symbol] The name of the command
  # @param arguments [Hash] Extra command arguments merged into the server/community context
  #
  # @return [ESM::ServiceCommand] The command, settled if it resolved within the poll window, else still pending
  #
  def call_async_command(command_name, arguments: {})
    command = create_async_command_for(command_name, arguments:)

    # Only the request that created the row dispatches, so a same-key retry (double-click, Turbo replay) dedupes to the
    # existing command instead of firing the work a second time.
    ESM::Service::API.call(:async_command, command_id: command.id) if command.previously_new_record?

    # Give a quick command a moment to land so it resolves in this response rather than flashing a spinner the client
    # poller clears a beat later. An already-settled row skips the wait; a retry rides the in-flight command's result.
    Poll.until(timeout: 1.second, every: 0.1.seconds) { command.reload.settled? } if command.pending?

    command
  end

  ##
  # Finds or creates the current user's ServiceCommand for this request, keyed on the request's idempotency key so a
  # retried request returns the same command rather than a duplicate. A newly built record is seeded with the current
  # server, command name, and the server/community context merged with arguments.
  #
  # @param command_name [String, Symbol] The name of the command
  # @param arguments [Hash] Extra command arguments merged into the base server/community context
  #
  # @return [ESM::ServiceCommand] The found or newly created command
  #
  # @raise [ActionController::ParameterMissing] When the request omits :idempotency_key
  #
  def create_async_command_for(command_name, arguments: {})
    ESM::ServiceCommand.find_or_create_by(
      user_id: current_user.id,
      idempotency_key: params.require(:idempotency_key)
    ) do |new_command|
      new_command.server = current_server
      new_command.community = command_community
      new_command.command_name = command_name
      new_command.arguments = command_context.merge(arguments)
    end
  end

  ##
  # The community a command runs against. Only one of the two sources is ever present: a community-scoped page has no
  # server in its URL, and a server-scoped page has no community in its URL.
  #
  # @return [ESM::Community, nil]
  #
  def command_community
    current_community || current_server&.community
  end

  ##
  # The identifiers handed to every command regardless of what the caller passes, so a command can always name where
  # it is running. A community-scoped command carries no server_id, which is also how it reaches Discord.
  #
  # @return [Hash]
  #
  def command_context
    context = {community_id: command_community.community_id}
    context[:server_id] = current_server.server_id if current_server

    context
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
    case reason
    when :unregistered
      "Link your Steam account on your account page first."
    when :disabled
      "This command isn't enabled on #{command_context_id}."
    when :not_allowlisted
      "You don't have permission to run this command on #{command_context_id}."
    when :server_offline
      "#{current_server.server_id} is offline. Try again once it's back up."
    else
      "You can't run that command right now."
    end
  end

  ##
  # What a denial names as the thing the command was refused on: the server when it targets one, otherwise the
  # community. Ids rather than display names, matching how the rest of the error copy identifies things.
  #
  # @return [String]
  #
  def command_context_id
    return current_server.server_id if current_server

    current_community.community_id
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
