# frozen_string_literal: true

module CooldownsHelper
  # Stands in for a wait with no end, so a spent usage allowance orders above every clock rather than below them.
  NEVER_ENDS = 10**9

  ##
  # How much of a cooldown is left, in whichever unit that cooldown counts in.
  #
  # A usage-count cooldown has no clock to read, so it reports the tally instead. Reading expires_at for one of those
  # would render a date the player is not actually waiting on.
  #
  # @param cooldown [ESM::Cooldown]
  #
  # @return [String]
  #
  def cooldown_time_left(cooldown)
    return "#{cooldown.cooldown_amount} of #{cooldown.cooldown_quantity} uses" if cooldown.cooldown_type == "times"
    return "Expired" unless cooldown.active?

    "#{ESM::Time.distance_of_time_in_words(cooldown.expires_at)} left"
  end

  ##
  # The player a cooldown belongs to, named for display.
  #
  # A row can outlive the account it was written for, and it keys on only one of steam_uid or user_id, so a player
  # that cannot be resolved still has to render as something an admin can act on rather than as a blank cell.
  #
  # @param cooldown [ESM::Cooldown]
  # @param player [ESM::User, nil] the resolved owner, when there is one
  #
  # @return [String]
  #
  def cooldown_player_name(cooldown, player)
    return player.username if player&.username.present?
    return cooldown.steam_uid if cooldown.steam_uid.present?

    "Unknown player"
  end

  ##
  # Where a cooldown applies.
  #
  # A null server_id is not missing data: every community-scoped command stores its cooldown that way, because there
  # was no server involved to pin it to.
  #
  # @param cooldown [ESM::Cooldown]
  # @param servers [Array<ESM::Server>]
  #
  # @return [String]
  #
  def cooldown_server_label(cooldown, servers)
    return "Community-wide" if cooldown.server_id.nil?

    servers.find { |server| server.id == cooldown.server_id }&.server_id || "Unknown server"
  end

  ##
  # Everything a row is matched and ordered on: the three filter values plus a sort key per column.
  #
  # @param cooldown [ESM::Cooldown]
  # @param player [ESM::User, nil] the row's resolved owner
  # @param servers [Array<ESM::Server>]
  #
  # @return [Hash]
  #
  def cooldown_row_attributes(cooldown, player, servers)
    cooldown_row_filters(cooldown, player, servers).merge(
      "data-sort-player" => cooldown_player_name(cooldown, player).downcase,
      "data-sort-command" => cooldown.command_name.to_s,
      "data-sort-server" => cooldown_server_label(cooldown, servers).downcase,
      "data-sort-remaining" => cooldown_remaining_seconds(cooldown).to_s
    )
  end

  ##
  # How long a cooldown still has to run, as one number the Remaining column can be ordered by.
  #
  # The column shows two unlike things, a clock and a tally, so ordering needs a single scale. A spent usage
  # allowance has no clock at all and only ends when somebody resets it, which makes it the longest wait there is
  # rather than an absent one; anything already finished sorts as zero whichever kind it was.
  #
  # @param cooldown [ESM::Cooldown]
  #
  # @return [Integer] seconds remaining, or NEVER_ENDS for a spent allowance
  #
  def cooldown_remaining_seconds(cooldown)
    return 0 unless cooldown.active?
    return NEVER_ENDS if cooldown.cooldown_type == "times"

    (cooldown.expires_at - ::Time.current).to_i
  end

  ##
  # The values a row is matched on, as data attributes.
  #
  # The same three the filters carry and the clear form submits, so a row hides for exactly the selection that would
  # have excluded it from the reset. A row with no resolvable player, or no server, answers blank and is therefore
  # narrowed out by naming either, which is what the command does with it too.
  #
  # @param cooldown [ESM::Cooldown]
  # @param player [ESM::User, nil] the row's resolved owner
  # @param servers [Array<ESM::Server>]
  #
  # @return [Hash]
  #
  def cooldown_row_filters(cooldown, player, servers)
    {
      "data-player" => player&.steam_uid.to_s,
      "data-command" => cooldown.command_name.to_s,
      "data-server" => servers.find { |server| server.id == cooldown.server_id }&.public_id.to_s
    }
  end

  ##
  # How a finished clear reports itself.
  #
  # A toast rather than an alert in the page, because the card underneath is replaced at the same moment: an outcome
  # pinned to a region that is about to be rewritten either vanishes with it or outlives the thing it described.
  #
  # @param result [Datum] the clear's outcome, carrying error and cleared
  #
  # @return [String] the turbo_stream that appends the toast
  #
  def cooldown_outcome_toast(result)
    return create_error_toast(result.error, title: "Couldn't clear", color: "red") if result.error.present?

    if result.cleared.to_i.zero?
      return create_info_toast("Those cooldowns had already run out.", title: "Nothing to clear", color: "blue")
    end

    create_success_toast(
      "#{pluralize(result.cleared, "cooldown")} cleared.",
      title: "Cooldowns cleared",
      color: "green"
    )
  end

  ##
  # The player filter's options, in SlimSelect's data shape.
  #
  # Searchable rather than a native select because the list reaches a hundred on the busiest communities, and a
  # native select's type-ahead only matches from the start of a name, which is the wrong way to hunt for a player.
  #
  # @param players [Array<ESM::User>]
  #
  # @return [Array<Hash>]
  #
  def cooldown_player_select_data(players)
    cooldown_any_option("Any player") +
      players.map { |player| {text: player.username, value: player.steam_uid} }
  end

  def cooldown_command_select_data(command_names)
    cooldown_any_option("Any command") + command_names.map { |name| {text: name, value: name} }
  end

  def cooldown_server_select_data(servers)
    cooldown_any_option("Any server") +
      servers.map { |server| {text: server.server_id, value: server.public_id} }
  end

  # A blank value is how the page says "any", and every filter opens on one: the page always arrives showing
  # everything it loaded.
  def cooldown_any_option(label)
    [{text: label, value: "", selected: true}]
  end
end
