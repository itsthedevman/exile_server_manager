# frozen_string_literal: true

class RegisteredController < AuthenticatedController
  before_action :check_for_registration!

  private

  def check_for_registration!
    return if current_user.registered?

    redirect_to register_path, alert: "You must link your Steam account before you can access that page"
  end
end
