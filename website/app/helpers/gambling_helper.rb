# frozen_string_literal: true

module GamblingHelper
  ##
  # The current player's gamble stats for a server, initialized to zeros when they
  # have never bet there so the card and modal render without a nil guard.
  #
  # @param server [ESM::Server] the server whose stats to load
  #
  # @return [ESM::UserGambleStat] the persisted or freshly initialized stats
  #
  def gamble_stat_for(server)
    ESM::UserGambleStat.find_or_initialize_by(server_id: server.id, user_id: current_user.id)
  end

  ##
  # URL the result poller watches until a dispatched bet settles. The command
  # carries its own server, so a caller holding only the command can still build it.
  #
  # @param command [ESM::ServiceCommand] the dispatched gamble command
  #
  # @return [String] the command's status endpoint path
  #
  def gamble_command_status_path(command)
    command_status_server_gamble_path(command.server.public_id, command)
  end

  ##
  # Whether the player has a live streak worth showing: a positive run with a
  # recorded last action. A stat with no bets yet has neither, so it reads inactive.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [Boolean]
  #
  def gamble_active_streak?(stat)
    stat.current_streak.positive? && stat.last_action.present?
  end

  ##
  # The streak strip's text, falling back to a muted default before the first bet.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [String] e.g. "3-win streak" or "2-loss streak", or "No active streak"
  #
  def gamble_streak_label(stat)
    return "No active streak" unless gamble_active_streak?(stat)

    "#{stat.current_streak}-#{(stat.last_action == "won") ? "win" : "loss"} streak"
  end

  ##
  # Bootstrap text color for the streak indicator.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [String] "text-success" on a win run, "text-danger" on a loss run,
  #   "text-muted" when no streak is active
  #
  def gamble_streak_class(stat)
    return "text-muted" unless gamble_active_streak?(stat)

    (stat.last_action == "won") ? "text-success" : "text-danger"
  end

  ##
  # The player's lifetime win/loss record.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [String] e.g. "129W / 143L"
  #
  def gamble_win_loss_record(stat)
    "#{stat.total_wins}W / #{stat.total_losses}L"
  end

  ##
  # Lifetime poptabs won minus lost. Negative when the house is ahead, which the
  # net color and sign key off of.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [Integer] the net poptabs balance
  #
  def gamble_net_poptabs(stat)
    stat.total_poptabs_won - stat.total_poptabs_loss
  end

  ##
  # Bootstrap text color for the net figure.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [String] "text-success" when up, "text-danger" when down, "text-muted"
  #   at exactly even
  #
  def gamble_net_class(stat)
    net = gamble_net_poptabs(stat)
    return "text-muted" if net.zero?

    net.positive? ? "text-success" : "text-danger"
  end

  ##
  # Win percentage as a rounded string, or a dash placeholder until the player has a
  # settled bet to divide by.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [String] e.g. "47%", or a dash placeholder when there are no settled bets
  #
  def gamble_win_rate(stat)
    total = stat.total_wins + stat.total_losses
    return "—" if total.zero?

    "#{((stat.total_wins.to_f / total) * 100).round}%"
  end

  ##
  # The win headline, with the poptab icon standing in for the amount's label.
  #
  # @param result [Data] the bet result view-model; reads #amount
  #
  # @return [ActiveSupport::SafeBuffer] e.g. "You won 5,000 <icon>"
  #
  def gamble_won_headline(result)
    safe_join(["You won ", poptabs(result.amount, inline: true)])
  end

  ##
  # The loss headline, with the poptab icon standing in for the amount's label.
  #
  # @param result [Data] the bet result view-model; reads #amount
  #
  # @return [ActiveSupport::SafeBuffer] e.g. "You lost 5,000 <icon>"
  #
  def gamble_lost_headline(result)
    safe_join(["You lost ", poptabs(result.amount, inline: true)])
  end

  ##
  # The line under the result headline: the player's new locker balance and the
  # streak this bet put them on.
  #
  # @param result [Data] the bet result view-model; reads #win, #locker_after, #streak
  #
  # @return [ActiveSupport::SafeBuffer] e.g. "New balance 351 <icon> · 1-loss streak"
  #
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

  ##
  # The player's stat tiles for the modal: a label, value, and accent-colored icon
  # per metric.
  #
  # @param stat [ESM::UserGambleStat] the player's stats for the server
  #
  # @return [Array<Data>] one istruct per tile, each with #label, #value, #icon,
  #   #accent, for the template to dot-access
  #
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

  ##
  # The server leaderboard rows for the modal: one per tracked record (streaks,
  # poptabs won and lost), each resolved to its holder and display value.
  #
  # @param server [ESM::Server] the server whose record holders to list
  #
  # @return [Array<Data>] the leaderboard rows, see {#gamble_leader_row}
  #
  def gamble_leaderboard(server)
    [
      gamble_leader_row("Longest active streak", server.longest_current_streak, :current_streak, icon: "bi-fire"),
      gamble_leader_row("Longest win streak", server.longest_win_streak, :longest_win_streak, icon: "bi-arrow-up-circle"),
      gamble_leader_row("Longest loss streak", server.longest_losing_streak, :longest_loss_streak, icon: "bi-arrow-down-circle"),
      gamble_leader_row("Most poptabs won", server.most_poptabs_won, :total_poptabs_won, icon: "bi-coin", as_poptabs: true),
      gamble_leader_row("Most poptabs lost", server.most_poptabs_lost, :total_poptabs_loss, icon: "bi-coin", as_poptabs: true)
    ]
  end

  ##
  # One leaderboard row as an istruct: its label and icon, the holder's name, and
  # the record value. Tolerates a nil stat (an unclaimed record) by falling back to
  # zero and a dash for the holder.
  #
  # @param label [String] the record's display name
  # @param stat [ESM::UserGambleStat, nil] the record-holding stat, if any
  # @param field [Symbol] the stat attribute holding the record value
  # @param icon [String] the Bootstrap icon class for the row
  # @param as_poptabs [Boolean] render the value with the poptab icon when true
  #
  # @return [Data] the row, with #label, #icon, #holder, #value
  #
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
