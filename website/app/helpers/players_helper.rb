# frozen_string_literal: true

module PlayersHelper
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

  # Bootstrap alert variant for the stuck/reset outcome: info while the command is still in flight, danger on failure,
  # success once the character has been reset.
  def stuck_result_variant(command)
    return "alert-info" unless command.settled?

    command.failed? ? "alert-danger" : "alert-success"
  end

  # Player-facing copy for the stuck/reset outcome, mirroring #stuck_result_variant's three states.
  def stuck_result_message(command)
    return "Resetting your character..." unless command.settled?
    return command.error_message if command.failed?

    "Your character has been reset - hop back in."
  end
end
