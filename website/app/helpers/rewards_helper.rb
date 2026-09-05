# frozen_string_literal: true

module RewardsHelper
  ##
  # The packages a player can be offered on this server.
  #
  # A package with nothing in it is an admin's half-finished edit rather than an offer, and the command refuses it
  # anyway, so it never reaches the list.
  #
  # @param server [ESM::Server]
  #
  # @return [Array<ESM::ServerReward>]
  #
  def reward_packages_for(server)
    server.server_rewards.enabled.select(&:rewards?)
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
    end
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
      {message: "Delivered. Head in game and enjoy.", css_class: "alert-success"}.to_datum
    when "partial"
      {message: "Some of it landed. What's left is still waiting for you below.", css_class: "alert-warning"}.to_datum
    else
      {message: "None of it could be delivered. It's all still yours, below.", css_class: "alert-danger"}.to_datum
    end
  end

  private

  def reward_cooldown_cache
    @reward_cooldown_cache ||= {}
  end
end
