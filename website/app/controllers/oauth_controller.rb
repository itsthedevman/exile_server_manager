# frozen_string_literal: true

class OAuthController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:steam, :discord]

  def discord
    user = ESM::User.from_omniauth(request.env["omniauth.auth"])
    sign_in_and_redirect user
  end

  def steam
    if !current_user
      flash[:error] = "You need to log in before attempting to register"

      redirect_to root_path
      return
    end

    if current_user.registered?
      flash[:warn] = {
        title: "Your Discord is already linked to Steam",
        body: "If you would like to change your Steam account, click the 'Deregister' button"
      }

      redirect_to edit_users_path
      return
    end

    steam_info = request.env["omniauth.auth"]

    if ESM::User.exists?(steam_uid: steam_info[:uid])
      session[:transferring_steam_uid] = steam_info[:uid]

      redirect_to edit_users_path(already_registered: true)
      return
    end

    current_user.update!(steam_uid: steam_info[:uid])

    flash[:success] = {
      title: "Welcome #{current_user.steam_data.username}!",
      body: "You are now registered with ESM<br/>We've sent you a message via Discord to help you get started"
    }

    ESM.bot.send_message(**current_user.welcome_message_hash)

    redirect_to edit_users_path
  end

  def failure
    redirect_to root_path
  end

  def login
  end
end
