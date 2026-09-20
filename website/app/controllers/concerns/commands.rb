# frozen_string_literal: true

module Commands
  extend ActiveSupport::Concern

  include CommandGating

  # The least time between two attempts at the same command on the same server, whatever came of the first one. A
  # community's own cooldown is a game rule and is only recorded once something actually happened, so a refusal can
  # otherwise be repeated as fast as a client can send it. This is the floor underneath that, well below the smallest
  # cooldown anyone configures.
  DISPATCH_FLOOR = 1.second

  # How long a dispatch that has not reported back still counts as running. The bot settles a command's row however it
  # ends, so anything older than this was being carried by a process that is now gone.
  DISPATCH_WINDOW = 1.minute

  private

  ##
  # Runs the CommandAccess verdict for command_name against the current user. On a denial, renders the
  # player-facing reason into the command's result slot and returns false so the caller can bail.
  #
  # An action that runs a command is also held to a rate of its own. Only those: a page reading the server puts the
  # same command name behind several frames at once, and they are cached rather than dispatched.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [Boolean] true if allowed, false if denied
  #
  def check_for_command_access(command_name)
    verdict = command_verdict(command_name)

    if !verdict.allowed?
      if verdict.reason == :server_offline && offline_server_visit?
        redirect_to server_path(current_server.public_id)
      else
        render_command_denied(command_denied_message(verdict.reason))
      end

      return false
    end

    return true if request.get?

    check_for_dispatch_rate(command_name)
  end

  ##
  # Whether this player may dispatch command_name right now, refusing the two ways a page can outrun the server it is
  # asking: several attempts at once, and one attempt after another as fast as they can be sent.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [Boolean] true when the dispatch may go ahead
  #
  def check_for_dispatch_rate(command_name)
    # Written before it is read, so two requests arriving together cannot both find it missing. The loser waits the
    # same moment the sender of a second attempt would.
    unless ESM.cache.write(dispatch_rate_key(command_name), true, expires_in: DISPATCH_FLOOR, unless_exist: true)
      render_command_denied("That was quick. Give it a moment and try again.")
      return false
    end

    return true unless command_dispatch_running?(command_name)

    render_command_denied("That's still running. Give it a moment.")
    false
  end

  ##
  # Whether this player already has an attempt at command_name out against the current server.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [Boolean]
  #
  def command_dispatch_running?(command_name)
    ESM::ServiceCommand
      .where(user_id: current_user.id, server_id: current_server&.id, command_name: command_name.to_s)
      .where(status: [:pending, :dispatched], created_at: DISPATCH_WINDOW.ago..)
      .exists?
  end

  def dispatch_rate_key(command_name)
    "command_dispatch/#{current_user.id}/#{current_server&.id}/#{command_name}"
  end

  ##
  # Whether this settled command's result still has to be read back from the game server.
  #
  # What a command changed is worth one fresh read, and the poller that asks for it stops on its own. Nothing makes
  # the browser stop, though, so every later request for the same settled command reads the cache the rest of the
  # page reads rather than reaching the server again.
  #
  # Each kind of read counts on its own: a territory action changes the territory and the player who paid for it, and
  # both are worth one look.
  #
  # @param command [ESM::ServiceCommand] the settled command
  # @param scope [Symbol] what is being read back
  #
  # @return [Boolean]
  #
  def first_read_after?(command, scope)
    key = "command_read/#{command.public_id}/#{scope}"

    ESM.cache.write(key, true, expires_in: DISPATCH_WINDOW, unless_exist: true)
  end

  ##
  # Whether a denial for an offline server should send the visitor to that server's own page rather than a 404. An
  # offline server is not a missing page, and its page already says it is offline.
  #
  # Only a plain page visit. A stream answers into the slot it was asked for, a frame would draw the whole server page
  # inside itself, and an action posted from a page should say what happened to it rather than navigate away. The
  # format is matched by symbol because Mime::Type#html? is true for anything with "html" in it, turbo streams included.
  #
  # @return [Boolean]
  #
  def offline_server_visit?
    current_server.present? && request.get? && request.format.symbol == :html && !turbo_frame_request?
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
    when :not_allowlisted, :not_a_member
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
