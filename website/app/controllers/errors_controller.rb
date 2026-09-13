# frozen_string_literal: true

class ErrorsController < ApplicationController
  # The layout reads the signed-in user, so a 500 the database caused fails again rendering its own page, and Rails
  # answers a failure inside the exceptions app with a bare plain-text response. The static page needs nothing.
  rescue_from StandardError, with: :render_static_error

  def show
    status = params[:status].to_i

    respond_to do |format|
      format.html { render :show, status:, locals: {status:} }
      format.json { render json: {error: Rack::Utils::HTTP_STATUS_CODES[status]}, status: }
      format.any { head status }
    end
  end

  private

  def render_static_error(exception)
    Rails.logger.error("Error page failed to render: #{exception.class}: #{exception.message}")

    render file: Rails.public_path.join("500.html"), layout: false, status: params[:status].to_i
  end
end
