# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  attr_reader :current_user

  def initialize(current_user: nil)
    @current_user = current_user
  end

  def pundit_policy(scope)
    Pundit.policy(current_user, scope)
  end
end
