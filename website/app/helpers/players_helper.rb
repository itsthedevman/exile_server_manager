# frozen_string_literal: true

module PlayersHelper
  # The balance actions on the admin player card: each takes a magnitude and a give/remove direction, folded into the
  # signed amount the player command expects. Kept here so the card iterates config rather than hard-coding three rows.
  PLAYER_BALANCE_ACTIONS = [
    {action: "money", label: "Pocket", icon: "cash-stack"},
    {action: "locker", label: "Locker", icon: "safe2"},
    {action: "respect", label: "Respect", icon: "star-fill"}
  ].freeze

  # The character actions: single-button, no amount. Kill confirms because it's destructive to the in-game character.
  PLAYER_CHARACTER_ACTIONS = [
    {action: "heal", label: "Heal", icon: "heart-pulse-fill", variant: "outline-success"},
    {action: "kill", label: "Kill", icon: "x-octagon-fill", variant: "outline-danger",
     confirm: "Kill this player's character? They'll die in-game."}
  ].freeze

  # Survival stats round to whole percents for the progress bars. They read nil
  # for a dead or absent character, but the view gates them behind #alive? so the
  # bars only render when there's a living character to describe.
  def player_health_percentage(player)
    player.health&.round
  end

  def player_hunger_percentage(player)
    player.hunger&.round
  end

  def player_thirst_percentage(player)
    player.thirst&.round
  end

  # The /me territory groups, in display order. Each is independent so the
  # overview shows only the groups that have members.

  # Stolen leads: it needs attention and can't be paid until recovered in-game.
  def player_stolen_territories(player)
    player.territories
      .select(&:stolen?)
      .sort_by { |territory| territory.name.to_s.downcase }
  end

  # Then payment-due (excluding stolen), most urgent first so overdue leads.
  def player_due_territories(player)
    player.territories
      .reject(&:stolen?)
      .select(&:payment_due_soon?)
      .sort_by { |territory| [territory.days_left_until_payment_due, territory.name.to_s.downcase] }
  end

  # Everything else, alphabetically.
  def player_upcoming_territories(player)
    player.territories
      .reject(&:stolen?)
      .reject(&:payment_due_soon?)
      .sort_by { |territory| territory.name.to_s.downcase }
  end

  # The admin listing arrives as plain rows off the query rather than a model, so these turn one row into what the
  # table shows.

  # The Exile database stores its datetimes without a zone, and the look-back sent to it is UTC, so the rows come
  # back read the same way. Interpreting them in the web host's zone instead would slide every "last seen" label.
  def player_timestamp(value)
    return if value.blank?

    ESM::Time.parse(value.to_s)
  end

  # An online player is described by when they connected, everyone else by when they left. A player with no
  # disconnect on record falls back to their connect time so the column is never blank.
  def player_last_seen_at(row)
    return player_timestamp(row[:last_connect_at]) if row[:online]

    player_timestamp(row[:last_disconnect_at]) || player_timestamp(row[:last_connect_at])
  end

  # Deaths of zero would divide by zero, so an unblemished player scores their kills outright.
  def player_kill_death_ratio(row)
    kills, deaths = row.values_at(:kills, :deaths)
    return kills.to_f.round(2) if deaths.to_i.zero?

    (kills.to_f / deaths).round(2)
  end

  # What the table's search box matches against. A name and a uid are the two things an admin arrives already holding.
  def player_search_terms(row)
    row.values_at(:name, :uid).join(" ").downcase
  end

  # The avatar for a player overview: the current user's on the self view, the viewed player's on the admin view. Falls
  # back to the default when there's no linked Steam avatar, which an unregistered UID always lacks.
  def player_avatar_url(player, viewing_self:)
    avatar_account(player, viewing_self:)&.steam_data&.avatar || image_url("default_steam_avatar.png")
  end

  def player_avatar_alt(player, viewing_self:)
    avatar_account(player, viewing_self:)&.steam_data&.username || "Default Steam Avatar"
  end

  # Whose account backs the overview avatar. The self view is the current user; the admin view is the viewed player's
  # linked account, which is nil when they never registered here (an admin can look up any UID off an RPT log or ban
  # list), leaving the avatar helpers to fall back to the default. Memoized per uid because both avatar helpers ask, and
  # the key? guard caches a miss so an unregistered UID isn't looked up twice.
  def avatar_account(player, viewing_self:)
    return current_user if viewing_self
    return if player.uid.blank?

    @avatar_accounts ||= {}
    return @avatar_accounts[player.uid] if @avatar_accounts.key?(player.uid)

    @avatar_accounts[player.uid] = ESM::User.find_by(steam_uid: player.uid)
  end

  ##
  # The at-a-glance status dressing for a player: the avatar ring color, plus a pill - color, icon, and word - that sits
  # beside the name so the state reads without leaning on color alone. Exile draws no dead-versus-never-spawned
  # distinction (it just drops the character row), so this is binary: a living character reads alive, anything else
  # reads as having no character. Memoized per uid because the avatar and pill partials each read fields off the one
  # result.
  #
  # @param player [ESM::Exile::Player]
  #
  # @return [Datum] responds to #ring_class, #pill_class, #icon_class, and #label
  #
  def player_status(player)
    @player_statuses ||= {}
    @player_statuses[player.uid] ||=
      if player.alive?
        Datum.new(
          ring_class: "border-success",
          pill_class: "text-success-emphasis bg-success-subtle border-success-subtle",
          icon_class: "bi-heart-fill",
          label: "Alive"
        )
      else
        Datum.new(
          ring_class: "border-danger",
          pill_class: "text-danger-emphasis bg-danger-subtle border-danger-subtle",
          icon_class: "bi-person-x",
          label: "No character"
        )
      end
  end

  # Which flavor of reset a command is, driving the copy and whether a single overview gets refreshed on settle: the
  # player's own self-service stuck reset, an admin reset of one player, or an admin reset of every character (the reset
  # command with no target).
  def reset_kind(command)
    return :self if command.command_name == "stuck"
    return :all if command.arguments[:target].blank?

    :player
  end

  # URL the service-command poller watches until a dispatched reset settles. Passes the command's public_id explicitly
  # (its to_param is the numeric id, but the status action looks it up by public_id, scoped to the current user).
  def player_command_status_path(command)
    command_status_server_players_path(command.server.public_id, command.public_id)
  end

  # The spinner label shown while a reset is still in flight.
  def reset_processing_label(command)
    case reset_kind(command)
    when :self then "Resetting your character..."
    when :all then "Resetting stuck players..."
    else "Resetting the character..."
    end
  end

  # The toast that announces a settled reset's outcome - success in green, failure in red.
  def reset_command_outcome_toast(command)
    return create_success_toast(reset_success_message(command), title: "Character reset", color: "green") if command.completed?

    create_error_toast(reset_command_failure_message(command), title: "Reset failed", color: "red")
  end

  # Success copy for a settled reset. Self-service speaks in the first person; an admin reset speaks about the character(s).
  def reset_success_message(command)
    case reset_kind(command)
    when :self then "Your character has been reset - hop back in."
    when :all then "Stuck players on #{command.server.server_name} have been reset."
    else "The character has been reset."
    end
  end

  # User-facing reason a reset didn't complete. A timeout is hedged because the delete may still have landed; a recorded
  # error_message is a rejection from the extension and is shown verbatim; anything else falls to a generic line.
  def reset_command_failure_message(command)
    return "The reset timed out - it may still have gone through. Refresh in a moment." if command.timed_out?
    return command.error_message if command.error_message.present?

    "The reset couldn't be completed. Try again in a moment."
  end

  def player_balance_actions
    PLAYER_BALANCE_ACTIONS
  end

  def player_character_actions
    PLAYER_CHARACTER_ACTIONS
  end

  # Whether an action takes a give/remove amount (money/locker/respect) rather than being a one-shot (heal/kill). Drives
  # which control the shared player-action partial renders.
  def player_balance_action?(action)
    PLAYER_BALANCE_ACTIONS.any? { |spec| spec[:action] == action }
  end

  # The display config for an action, from whichever group owns it - so a turbo response can re-render the region for the
  # action a command carries.
  def player_action_spec(action)
    (PLAYER_BALANCE_ACTIONS + PLAYER_CHARACTER_ACTIONS).find { |spec| spec[:action] == action }
  end

  # DOM id for one player action's region, so a turbo response replaces just that action's control after it fires.
  def player_action_region_id(action)
    "player_action_#{action}"
  end

  # The toast announcing a settled player action: a balance change reports its before -> after, heal/kill a plain done.
  def player_action_outcome_toast(command)
    return create_success_toast(player_action_success_message(command), title: "Action complete", color: "green") if command.completed?
    return create_info_toast("The action is still processing - refresh in a moment to confirm.", title: "Working", color: "blue") unless command.settled?

    create_error_toast(player_action_failure_message(command), title: "Action failed", color: "red")
  end

  def player_action_success_message(command)
    case command.arguments[:action]
    when "heal" then "Player healed."
    when "kill" then "Player killed."
    else player_balance_change_message(command)
    end
  end

  # "Locker: 10,000 → 15,000" when the command reported both ends, else a plain confirmation.
  def player_balance_change_message(command)
    result = command.result.to_h.with_indifferent_access
    previous = result[:previous_amount]
    current = result[:new_amount]
    noun = player_action_noun(command.arguments[:action])

    return "#{noun} updated." if previous.nil? || current.nil?

    "#{noun}: #{number_with_delimiter(previous)} → #{number_with_delimiter(current)}"
  end

  def player_action_noun(action)
    {"money" => "Pocket", "locker" => "Locker", "respect" => "Respect"}.fetch(action, "Balance")
  end

  # User-facing reason a player action didn't complete. Timeout is hedged (the in-game side may still have happened); a
  # recorded error_message is the extension's own rejection, shown verbatim; anything else falls to a generic line.
  def player_action_failure_message(command)
    return "The server didn't respond in time. Check in-game before trying again." if command.timed_out?
    return command.error_message if command.error_message.present?

    "Something went wrong running that action. Please try again."
  end
end
