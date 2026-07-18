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
