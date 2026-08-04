# frozen_string_literal: true

module Dev
  ##
  # Signs in as an existing user, skipping the Discord OAuth round trip.
  #
  # The route is declared inside the `Rails.env.local?` block in `config/routes.rb`; `ensure_local!`
  # re-checks per request so the action stays unreachable even if the route ever escapes that block.
  #
  class SessionsController < ApplicationController
    before_action :ensure_local!

    def create
      user = ESM::User.find_by(discord_id: params[:discord_id])

      return render_unknown_user if user.nil?

      sign_in(user)

      redirect_to(params[:return_to].presence || root_path)
    end

    private

    def ensure_local!
      raise ActionController::RoutingError, "Not Found" if !Rails.env.local?
    end

    def render_unknown_user
      known_users = ESM::User.order(:id).limit(25).pluck(:discord_id, :discord_username, :steam_uid)
      listing = known_users.map do |discord_id, username, steam_uid|
        "  #{discord_id}  #{username || "(no username)"}  #{steam_uid || "(unregistered)"}"
      end

      render plain: <<~TEXT, status: :not_found
        No user with discord_id #{params[:discord_id].inspect}.

        Known users (discord_id, username, steam_uid):
        #{listing.join("\n")}
      TEXT
    end
  end
end
