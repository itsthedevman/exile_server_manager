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

  private

  def reward_cooldown_cache
    @reward_cooldown_cache ||= {}
  end
end
