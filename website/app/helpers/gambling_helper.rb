# frozen_string_literal: true

module GamblingHelper
  # TODO: Docs
  def gamble_stat_for(server)
    ESM::UserGambleStat.find_or_initialize_by(server_id: server.id, user_id: current_user.id)
  end

  # TODO: Docs
  def gamble_active_streak?(stat)
    stat.current_streak.positive? && stat.last_action.present?
  end

  # TODO: Docs
  def gamble_streak_label(stat)
    return "No active streak" unless gamble_active_streak?(stat)

    "#{stat.current_streak}-#{(stat.last_action == "won") ? "win" : "loss"} streak"
  end

  # TODO: Docs
  def gamble_streak_class(stat)
    return "text-muted" unless gamble_active_streak?(stat)

    (stat.last_action == "won") ? "text-success" : "text-danger"
  end

  # TODO: Docs
  def gamble_win_loss_record(stat)
    "#{stat.total_wins}W / #{stat.total_losses}L"
  end

  # TODO: Docs
  def gamble_net_poptabs(stat)
    stat.total_poptabs_won - stat.total_poptabs_loss
  end

  # TODO: Docs
  def gamble_net_class(stat)
    net = gamble_net_poptabs(stat)
    return "text-muted" if net.zero?

    net.positive? ? "text-success" : "text-danger"
  end

  # TODO: Docs
  def gamble_win_rate(stat)
    total = stat.total_wins + stat.total_losses
    return "—" if total.zero?

    "#{((stat.total_wins.to_f / total) * 100).round}%"
  end

  # TODO: Docs
  def gamble_won_headline(result)
    safe_join(["You won ", poptabs(result.amount, inline: true)])
  end

  # TODO: Docs
  def gamble_lost_headline(result)
    safe_join(["You lost ", poptabs(result.amount, inline: true)])
  end

  # TODO: Docs
  def gamble_result_subline(result)
    kind = result.win ? "win" : "loss"

    safe_join(
      [
        "New balance ",
        poptabs(result.locker_after, inline: true),
        " · #{result.streak}-#{kind} streak"
      ]
    )
  end

  # TODO: Docs
  def gamble_personal_tiles(stat)
    [
      {label: "Wins", value: stat.total_wins, icon: "bi-trophy", accent: "text-success"},
      {label: "Losses", value: stat.total_losses, icon: "bi-x-octagon", accent: "text-danger"},
      {label: "Poptabs won", value: poptabs(stat.total_poptabs_won, inline: true), icon: "bi-coin", accent: "text-success"},
      {label: "Poptabs lost", value: poptabs(stat.total_poptabs_loss, inline: true), icon: "bi-coin", accent: "text-danger"},
      {label: "Current streak", value: gamble_streak_label(stat), icon: "bi-fire", accent: "text-warning"},
      {label: "Longest win streak", value: stat.longest_win_streak, icon: "bi-arrow-up-circle", accent: "text-success"},
      {label: "Longest loss streak", value: stat.longest_loss_streak, icon: "bi-arrow-down-circle", accent: "text-danger"},
      {label: "Win rate", value: gamble_win_rate(stat), icon: "bi-percent", accent: "text-info"}
    ].map(&:to_istruct)
  end

  # TODO: Docs
  def gamble_leaderboard(server)
    [
      gamble_leader_row("Longest active streak", server.longest_current_streak, :current_streak, icon: "bi-fire"),
      gamble_leader_row("Longest win streak", server.longest_win_streak, :longest_win_streak, icon: "bi-arrow-up-circle"),
      gamble_leader_row("Longest loss streak", server.longest_losing_streak, :longest_loss_streak, icon: "bi-arrow-down-circle"),
      gamble_leader_row("Most poptabs won", server.most_poptabs_won, :total_poptabs_won, icon: "bi-coin", as_poptabs: true),
      gamble_leader_row("Most poptabs lost", server.most_poptabs_lost, :total_poptabs_loss, icon: "bi-coin", as_poptabs: true)
    ]
  end

  # TODO: Docs
  def gamble_leader_row(label, stat, field, icon:, as_poptabs: false)
    value = stat&.public_send(field) || 0

    {
      label:,
      icon:,
      holder: stat&.user&.username || "—",
      value: as_poptabs ? poptabs(value, inline: true) : value
    }.to_istruct
  end
end
