# frozen_string_literal: true

module CommunitiesHelper
  # Everything the Community Type card and its modal say, resolved from which mode the community is in now. Kept here
  # rather than branched in two templates so the button, the modal title, and the consequence can't describe different
  # directions.
  ModeSwitch = Data.define(:target_enabled, :action_label, :current_summary, :consequence)

  ##
  # The copy and target state for switching this community's type.
  #
  # @param community [ESM::Community]
  #
  # @return [ModeSwitch]
  #
  def change_mode_switch(community)
    if community.player_mode_enabled?
      ModeSwitch.new(
        target_enabled: false,
        action_label: "Switch to a server community",
        current_summary: "Your members use ESM on servers that other communities host.",
        consequence: <<~STRING
          You'll be able to register your own servers, choose which commands run in which channels, and run other admin commands.
        STRING
      )
    else
      ModeSwitch.new(
        target_enabled: true,
        action_label: "Switch to a player community",
        current_summary: "This community hosts its own Exile servers.",
        consequence: <<~STRING
          Your members use ESM on servers that other communities host.
          Enabling this will allow you and your friends can run player commands in any of your Discord channels.
        STRING
      )
    end
  end

  ##
  # Why the community type cannot be changed right now, or nil when this user may change it.
  #
  # The card states the reason in place of the control rather than showing nothing: a card that quietly loses its button
  # is a mystery, while a stated reason teaches what would have to change.
  #
  # @param community [ESM::Community]
  # @param user [ESM::User]
  #
  # @return [String, nil]
  #
  def change_mode_lock_reason(community, user)
    return "Only the community owner can change this." unless community.owned_by?(user)

    # Leaving player mode is always allowed, so the servers rule only bites on the way in.
    return if community.player_mode_enabled? || community.can_enable_player_mode?

    "Remove this community's servers first. A player community can't host its own."
  end
end
