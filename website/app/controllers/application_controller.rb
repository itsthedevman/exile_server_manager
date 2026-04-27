# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Exceptions
  include RescueHandlers

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: {
    safari: "13+",
    chrome: "80+",
    firefox: "80+",
    edge: "80+"
  }

  delegate :create_toast,
    :create_info_toast, :create_success_toast,
    :create_warn_toast, :create_error_toast,
    :hide_modal,
    to: :helpers

  def not_found!
    raise NotFoundError.new
  end

  private

  # Forward the login request if the user isn't logged in yet
  def authenticate_user!
    return super if user_signed_in?

    # Store where they were trying to go
    store_location_for(:user, request.fullpath)

    redirect_to login_path
  end
end
