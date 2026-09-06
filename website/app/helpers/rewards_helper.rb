# frozen_string_literal: true

module RewardsHelper
  ##
  # The one package the page shows outright.
  #
  # Only the default is ever listed. Every other package is claimed by typing its ID, which is what lets an owner run
  # one as a coupon: something handed out for joining their Discord, say. A dropdown of every package would put all of
  # them on the page and there is nothing else stopping a player from taking one the moment they can see it.
  #
  # Nil when the default has nothing in it, which is an admin's half-finished edit rather than an offer. The command
  # refuses that package anyway, so a Redeem button for it could only fail. Nil too once the player has spent it for
  # good, since a row that will never be actionable again is not worth the space.
  #
  # @param server [ESM::Server]
  #
  # @return [ESM::ServerReward, nil]
  #
  def reward_default_package_for(server)
    package = server.server_rewards.enabled.default.first
    return if package.nil? || !package.rewards?
    return if reward_package_exhausted?(server, package)

    package
  end

  ##
  # What this player is still owed on this server, if anything. One row at most, capped by the unique index.
  #
  # @param server [ESM::Server]
  #
  # @return [ESM::ServerRewardClaim, nil]
  #
  def reward_claim_for(server)
    current_user.server_reward_claims.find_by(server_id: server.id)
  end

  ##
  # The cooldown standing between this player and this package, whether or not it is still running.
  #
  # Asked through ESM::Cooldown.scope_for rather than a query of its own: which column a cooldown keys on depends on
  # whether the command is registration-gated, and a second copy of that rule here is a second place for it to drift.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [ESM::Cooldown, nil]
  #
  def reward_cooldown_for(server, package)
    reward_cooldown_cache[[server.id, package.reward_id]] ||= ESM::Cooldown.scope_for(
      command_name: "reward",
      scope_key: package.reward_id,
      user: current_user,
      registered: ESM::Command[:reward].requirements.registration?,
      community: server.community,
      server:
    ).first
  end

  ##
  # Whether the player can take this package right now.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [Boolean]
  #
  def reward_package_available?(server, package)
    cooldown = reward_cooldown_for(server, package)

    cooldown.nil? || !cooldown.active?
  end

  ##
  # Whether this package is spent for good rather than waiting on a clock.
  #
  # A usage-count cooldown never comes back, so its row would sit on the page forever saying so. A time-based one does
  # come back, and when is worth reading, so that one stays put.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [Boolean]
  #
  def reward_package_exhausted?(server, package)
    cooldown = reward_cooldown_for(server, package)

    cooldown.present? && cooldown.cooldown_type == "times" && cooldown.active?
  end

  ##
  # How many more times a package can be taken, when what limits it is a count rather than a clock.
  #
  # This is the only thing that explains why a package a player just redeemed is still sitting there offering itself.
  # Nil for a clock-based package, and nil for one nobody has taken yet: the count only exists once a cooldown row
  # does, and reading the configuration instead would promise a number the command has not agreed to.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [String, nil]
  #
  def reward_uses_remaining_label(server, package)
    cooldown = reward_cooldown_for(server, package)
    return if cooldown.nil? || cooldown.cooldown_type != "times"

    remaining = cooldown.cooldown_quantity - cooldown.cooldown_amount
    return if remaining < 1

    "#{pluralize(remaining, "use")} left"
  end

  ##
  # What the package row says about when it can next be taken.
  #
  # A usage-count cooldown has no clock to read, so it says so plainly instead of rendering a date the player is not
  # actually waiting on.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_availability_label(server, package)
    return "Available" if reward_package_available?(server, package)

    cooldown = reward_cooldown_for(server, package)
    return "No uses left" if cooldown.cooldown_type == "times"

    "Available in #{ESM::Time.distance_of_time_in_words(cooldown.expires_at)}"
  end

  ##
  # Why a package someone asked for by code cannot be taken, or nil when it can.
  #
  # Answered as a sentence rather than the badge a listed package wears, because there is no row to hang a badge on:
  # a code that resolves to a cooldown never makes it onto the page.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [String, nil]
  #
  def reward_unavailable_message(server, package)
    return if reward_package_available?(server, package)

    cooldown = reward_cooldown_for(server, package)
    return "This reward is no longer available." if cooldown.cooldown_type == "times"

    "That code is on cooldown. It comes back in #{ESM::Time.distance_of_time_in_words(cooldown.expires_at)}."
  end

  ##
  # A package's reward ID, reduced to something an element id can be built out of. Owners name their packages, and a
  # name is not obliged to be a legal id.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_key(package)
    package.reward_id.parameterize(separator: "_")
  end

  ##
  # A package row's id, so a code looked up twice replaces its own row instead of stacking another copy of it.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_dom_id(package)
    "reward_package_#{reward_package_key(package)}"
  end

  ##
  # A package's name for display. Every package has an ID and only some have been given a name, so the ID stands in.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_name(package)
    package.name.presence || package.reward_id.titleize
  end

  ##
  # The one-line summary of what a package or claim holds, as "5,000 poptabs · 100 respect · 3 items".
  #
  # @param contents [Datum] a package's or claim's #contents
  #
  # @return [String]
  #
  def reward_contents_summary(contents)
    parts = []

    parts << "#{number_with_delimiter(contents.player_poptabs)} poptabs" if contents.player_poptabs.positive?
    parts << "#{number_with_delimiter(contents.locker_poptabs)} locker" if contents.locker_poptabs.positive?
    parts << "#{number_with_delimiter(contents.respect)} respect" if contents.respect.positive?
    parts << pluralize(contents.items.size, "item") if contents.items.present?
    parts << pluralize(contents.vehicles.size, "vehicle") if contents.vehicles.present?

    parts.join(" · ")
  end

  ##
  # Where a vehicle is headed, in words a player would use.
  #
  # @param vehicle [Datum] one entry from #contents
  #
  # @return [String]
  #
  def reward_vehicle_destination(vehicle)
    case vehicle.spawn_location
    when "nearby"
      "spawns next to you"
    when "virtual_garage"
      "goes to a virtual garage"
    else
      "you choose where it goes"
    end
  end

  ##
  # Why the last delivery attempt did not finish, one line per bucket that failed.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [Array<String>]
  #
  def reward_claim_failures(claim)
    failures = claim.state_details[:failures]
    return [] if failures.blank?

    failures.map { |failure| "#{failure[:name]}: #{failure[:reason]}" }
  end

  ##
  # Whether this vehicle's delivery form needs a territory picked for it.
  #
  # A vehicle already bound for a garage needs one, and so does one whose destination the player has yet to choose,
  # since choosing the garage is one of the two answers.
  #
  # @param vehicle [Datum] one entry from #contents
  #
  # @return [Boolean]
  #
  def reward_vehicle_needs_territory?(vehicle)
    ["virtual_garage", "player_decides"].include?(vehicle.spawn_location)
  end

  ##
  # The block holding a set of vehicle fields.
  #
  # Under a package it is set in and given its own ground, so the questions read as belonging to the offer above them
  # rather than as another entry in the list. Inside a claim it gets neither: the claim box is already a panel, and
  # there is nothing above the fields there for them to belong to.
  #
  # @param grouped [Boolean] whether these fields sit under something they answer for
  #
  # @return [String]
  #
  def reward_vehicle_group_classes(grouped)
    return "mt-2 ms-3 p-2 rounded bg-body-secondary" if grouped

    "mt-2"
  end

  ##
  # One vehicle's row inside the delivery block. Every row after the first carries a rule, since the block is one
  # tinted panel and the icons alone do not separate three vehicles from each other.
  #
  # @param index [Integer] the vehicle's position in the package or claim
  #
  # @return [String]
  #
  def reward_vehicle_row_classes(index)
    return "mt-1" if index.zero?

    "border-top pt-2 mt-2"
  end

  ##
  # The territory picker's column, hidden up front for a vehicle whose destination is still the player's to choose.
  #
  # Hidden server-side rather than by the controller that takes over afterwards, because the picker fills itself from
  # a lazy frame the moment it is on screen. Waiting for JavaScript to hide it is a round trip to the game server for
  # a question the player has not been asked yet.
  #
  # @param vehicle [Datum] one entry from #contents
  #
  # @return [String]
  #
  def reward_territory_field_classes(vehicle)
    return "col-12 col-sm-6 d-none" if vehicle.spawn_location == "player_decides"

    "col-12 col-sm-6"
  end

  ##
  # The destinations a player may choose between when the admin left it to them.
  #
  # @return [Array<Array(String, String)>]
  #
  def reward_spawn_location_options
    [["Spawn it next to me", "nearby"], ["Store it in a virtual garage", "virtual_garage"]]
  end

  ##
  # The territory dropdown's options, labelled with how much garage room is left.
  #
  # Territories whose garage is already full are left out rather than shown greyed: the game refuses them, so
  # offering one would only trade a clear absence for a failed delivery.
  #
  # @param territories [Array<Datum>] rows from the reward_territories query
  #
  # @return [Array<Array(String, String)>]
  #
  def reward_territory_options(territories)
    territories.filter_map do |territory|
      capacity = territory[:garage_capacity]
      free = capacity.to_i - territory[:vehicle_count].to_i
      next if capacity.nil? || free < 1

      name = territory[:esm_custom_id].presence || territory[:territory_name]
      ["#{name} (#{free} of #{capacity} free)", territory[:id]]
    end.sort_by { |label, _id| label.downcase }
  end

  ##
  # What the panel says about the attempt that just finished.
  #
  # @param command [ESM::ServiceCommand] the settled command
  #
  # @return [Datum, nil]
  #
  def reward_outcome(command)
    return if command.nil? || !command.settled?

    if command.error_message.present?
      return {message: command.error_message, css_class: "alert-danger"}.to_datum
    end

    case command.result&.dig(:state)
    when "success"
      {message: "Delivered. Enjoy!", css_class: "alert-success"}.to_datum
    when "partial"
      {message: "Some of it landed. What's left is still waiting for you below.", css_class: "alert-warning"}.to_datum
    else
      {message: "None of it could be delivered. You may still redeem them below.", css_class: "alert-danger"}.to_datum
    end
  end

  private

  def reward_cooldown_cache
    @reward_cooldown_cache ||= {}
  end
end
