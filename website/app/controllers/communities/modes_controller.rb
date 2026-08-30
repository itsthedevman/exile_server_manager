# frozen_string_literal: true

module Communities
  ##
  # Switches a community between player mode and server mode.
  #
  # Deliberately outside the settings form. The rest of that page is open to anyone with dashboard access, while what
  # kind of community this is stays the owner's call, the same gate the Discord command applies.
  #
  class ModesController < AuthenticatedController
    before_action :check_for_community_access!

    def update
      not_found! unless current_community.owned_by?(current_user)

      enabled = ActiveModel::Type::Boolean.new.cast(params.require(:player_mode_enabled))

      # The switch is rendered disabled in this case, so reaching here means the request came from somewhere else or
      # the last server was registered while the page sat open.
      if enabled && !current_community.can_enable_player_mode?
        flash[:warn] = "Remove this community's servers before switching it to a player community."
        return redirect_to edit_community_path(current_community)
      end

      current_community.update!(player_mode_enabled: enabled)
      flash[:success] = success_message(enabled)

      redirect_to edit_community_path(current_community)
    end

    private

    def success_message(enabled)
      return "#{current_community.community_name} is now a player community." if enabled

      "#{current_community.community_name} is now a server community, and can register servers."
    end
  end
end
