# frozen_string_literal: true

module PlayersHelper
  # Survival and pocket stats only exist while the player has a living character.
  # When the Exile player row is absent, damage/hunger/thirst/money all come back nil.
  def player_alive?(player)
    !player.damage.nil?
  end

  def player_health_percentage(player)
    return if player.damage.nil?

    ((1.0 - player.damage) * 100).round
  end

  def player_hunger_percentage(player)
    player.hunger&.round
  end

  def player_thirst_percentage(player)
    player.thirst&.round
  end

  def player_kill_death_ratio(player)
    return player.kills.to_f unless player.deaths.positive?

    (player.kills.to_f / player.deaths).round(2)
  end

  def territory_payment_status(territory)
    days = territory.days_left_until_payment_due

    label, urgent =
      if days.nil?
        ["Payment status unavailable", false]
      elsif days.negative?
        ["Payment overdue", true]
      elsif days.zero?
        ["Payment due today", true]
      elsif days == 1
        ["Payment due tomorrow", false]
      else
        ["Payment due in #{days} days", false]
      end

    tag.span(label, class: urgent ? "text-danger fw-medium" : "text-muted")
  end
end
