# frozen_string_literal: true

module RewardClaimsHelper
  # What each state means to the person looking at the table, rather than what the delivery code calls it. Ordered
  # the way the listing is ordered, so the filter reads down the table.
  CLAIM_STATES = {
    "failed" => {label: "Stuck", badge: "text-bg-danger"},
    "in_flight" => {label: "Delivering", badge: "text-bg-info"},
    "waiting" => {label: "Waiting", badge: "text-bg-secondary"}
  }.freeze

  # How long a delivery may sit unfinished before the row stops claiming one is running. A delivery is one round trip
  # to the server and settles in seconds, so a minute is already far longer than any of them take.
  STALE_DELIVERY_AFTER = 1.minute

  ##
  # Whether this community has anywhere a claim could come from.
  #
  # Claims are only ever created by the v2 reward command, so a community running nothing but v1 servers would get a
  # page that can never have a row on it.
  #
  # @param community [ESM::Community]
  #
  # @return [Boolean]
  #
  def reward_claims_manageable?(community)
    community.servers.any?(&:ui_v2?)
  end

  ##
  # One claim, named the way an admin would say it out loud.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [String]
  #
  def reward_claim_label(claim)
    "#{reward_claim_player_name(claim)}'s claim on #{reward_claim_server_label(claim)}"
  end

  def reward_claim_player_name(claim)
    claim.user&.username.presence || "Unknown player"
  end

  def reward_claim_server_label(claim)
    claim.server&.server_id.presence || "Unknown server"
  end

  ##
  # The package this claim was redeemed from, by the code a player would have typed.
  #
  # The code rather than the package's name because the package may well be gone: contents are copied into a claim so
  # that editing or deleting one cannot change what somebody is already owed.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [String, nil] nil when an admin built the claim by hand
  #
  def reward_claim_package_code(claim)
    claim.reward_id.presence
  end

  def reward_claim_state_label(claim)
    return "Interrupted" if reward_claim_delivery_stalled?(claim)

    CLAIM_STATES.dig(claim.state, :label) || claim.state.humanize
  end

  def reward_claim_state_badge_class(claim)
    return "text-bg-warning" if reward_claim_delivery_stalled?(claim)

    CLAIM_STATES.dig(claim.state, :badge) || "text-bg-secondary"
  end

  ##
  # What the state means for the player.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [String]
  #
  def reward_claim_state_summary(claim)
    return "A delivery started but did not finish. The player can try again." if
      reward_claim_delivery_stalled?(claim)

    case claim.state
    when "failed"
      "Delivery failed #{ESM::Command::Server::Reward::MAX_DELIVERY_ATTEMPTS} times and stopped. " \
        "This player cannot redeem anything else on this server until the claim is resolved."
    when "in_flight"
      "A delivery is running right now."
    else
      "This will be delivered the next time the player tries to receive it."
    end
  end

  ##
  # Whether a delivery has been running long enough that it is not running any more.
  #
  # The row is the only place this shows up. Nothing is blocked by it: the reward command finds a claim whatever
  # state it is in, so the player can try again without anyone here doing anything first.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [Boolean]
  #
  def reward_claim_delivery_stalled?(claim)
    claim.in_flight? && claim.updated_at < STALE_DELIVERY_AFTER.ago
  end

  ##
  # How much of the claim's delivery allowance is gone, when any of it is.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [String, nil]
  #
  def reward_claim_attempts_summary(claim)
    return if claim.attempt_count.zero?

    "#{claim.attempt_count} of #{ESM::Command::Server::Reward::MAX_DELIVERY_ATTEMPTS} attempts"
  end

  ##
  # What the player gets back when a claim is deleted.
  #
  # Deleting one is not purely destructive and the modal should not read as though it is. An unfinished claim is what
  # stops a player redeeming anything else on that server, and the package it came from never went on cooldown,
  # because that only happens once a delivery has actually landed.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [String]
  #
  def reward_claim_delete_consequence(claim)
    code = reward_claim_package_code(claim)
    reopened = "#{reward_claim_player_name(claim)} can redeem rewards on " \
      "#{reward_claim_server_label(claim)} again once this claim is gone"

    if code.nil?
      return "#{reopened}. An admin put this claim together by hand, so there is no package behind it for them to " \
        "redeem again."
    end

    "#{reopened}, #{code} included. A package only goes on cooldown once it has been delivered."
  end

  ##
  # Whether this claim needs someone here before the player can try again.
  #
  # Only a stopped claim does. Every other state is one the reward command will pick up on its own, so a button
  # offered for them would change how the row reads and nothing else.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [Boolean]
  #
  def reward_claim_retryable?(claim)
    claim.failed?
  end

  ##
  # Data attributes the browser narrows the table by. Every filter is a value the row either carries or does not.
  #
  # @param claim [ESM::ServerRewardClaim]
  #
  # @return [Hash]
  #
  def reward_claim_row_attributes(claim)
    {
      "data-player" => claim.user&.discord_id.to_s,
      "data-server" => claim.server&.public_id.to_s,
      "data-state" => claim.state
    }
  end

  ##
  # Where the claim editor submits to, which is a claim that exists or the community's whole set.
  #
  # @param claim [ESM::ServerRewardClaim, nil] nil while one is being started
  #
  # @return [String]
  #
  def reward_claim_form_url(claim)
    return community_reward_claims_path(current_community) if claim.nil?

    community_server_reward_claim_path(current_community, claim.server, claim.user)
  end

  def reward_claim_form_method(claim)
    claim.nil? ? :post : :patch
  end

  def reward_claim_form_submit(claim)
    claim.nil? ? "Add rewards" : "Update claim"
  end

  def reward_claim_form_title(claim)
    claim.nil? ? "Add rewards" : reward_claim_label(claim)
  end

  def reward_claim_form_subtitle(claim)
    return "Adds these rewards to anything the player is already owed" if claim.nil?

    "Replaces what this player is owed with the rewards below"
  end

  def reward_claim_form_server_data(servers, selected)
    servers.map do |server|
      {text: server.server_id, value: server.public_id, selected: server.public_id == selected}
    end
  end

  ##
  # Which servers in reach of this form cannot hand out a vehicle yet, when any of them cannot.
  #
  # The vehicle fields are drawn whichever server is picked, because the picker sits in the same form and changing it
  # reloads nothing. Naming the servers up front is what keeps a filled in reward from being refused at the end of it.
  # An edit has no picker, so only its own server is in reach.
  #
  # @param claim [ESM::ServerRewardClaim, nil]
  # @param servers [Array<ESM::Server>]
  #
  # @return [String, nil]
  #
  def reward_claim_form_vehicle_note(claim, servers)
    reachable = claim.nil? ? servers : [claim.server].compact
    too_old = reachable.reject { |server| reward_packages_vehicles_supported?(server) }
    return if too_old.empty?

    "#{too_old.join_map(", ", &:server_id)} cannot hand out vehicles yet. That needs extension " \
      "#{ESM::Command::Server::Reward::MINIMUM_SERVER_VERSION}."
  end

  def reward_claim_player_select_data(players)
    reward_claim_any_option("Any player") +
      players.map { |player| {text: player.username, value: player.discord_id} }
  end

  def reward_claim_server_select_data(servers)
    reward_claim_any_option("Any server") +
      servers.map { |server| {text: server.server_id, value: server.public_id} }
  end

  def reward_claim_state_select_data
    reward_claim_any_option("Any state") +
      CLAIM_STATES.map { |state, details| {text: details[:label], value: state} }
  end

  # A blank value is how the page says "any", and every filter opens on one: the page always arrives showing
  # everything it loaded.
  def reward_claim_any_option(label)
    [{text: label, value: "", selected: true}]
  end
end
