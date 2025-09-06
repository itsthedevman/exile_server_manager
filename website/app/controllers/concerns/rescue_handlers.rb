# frozen_string_literal: true

module RescueHandlers
  extend ActiveSupport::Concern

  included do
    # === RESCUE HANDLERS ===
    rescue_from Exceptions::NotFoundError, with: :render_not_found
    rescue_from Exceptions::UnauthorizedError, with: :render_unauthorized
    rescue_from Exceptions::PayloadTooLargeError, with: :render_payload_too_large
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    # Validation failures with save!/create!/update!
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_errors

    # Missing required parameters (like params.require(:user))
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

    # Unique constraint violations at DB level
    rescue_from ActiveRecord::RecordNotUnique, with: :render_duplicate_record

    # Foreign key constraint violations
    rescue_from ActiveRecord::InvalidForeignKey, with: :render_invalid_reference

    # General SQL/database errors
    rescue_from ActiveRecord::StatementInvalid, with: :render_database_error
  end

  private

  def render_not_found(exception = nil)
    respond_to do |format|
      format.html { render template: "errors/not_found_404", status: :not_found }
      format.json { render json: {error: "Not found"}, status: :not_found }
      format.turbo_stream do
        render turbo_stream: create_error_toast("The requested item was not found"),
          status: :not_found
      end
    end
  end

  def render_unauthorized(exception = nil)
    message = exception&.message || "Unauthorized"

    respond_to do |format|
      format.html { redirect_to login_path, alert: message }
      format.json { render json: {error: message}, status: :unauthorized }
      format.turbo_stream do
        render turbo_stream: create_error_toast(message), status: :unauthorized
      end
    end
  end

  def render_payload_too_large(exception)
    message = exception.message || "Request payload too large"

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: message) }
      format.json { render json: {error: message}, status: :payload_too_large }
      format.turbo_stream do
        render turbo_stream: create_error_toast(message), status: :payload_too_large
      end
    end
  end

  def render_validation_errors(exception)
    record = exception.record
    errors = record.errors.full_messages.join(", ")

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: "Validation failed: #{errors}") }
      format.json { render json: {errors: record.errors}, status: :unprocessable_entity }
      format.turbo_stream do
        render turbo_stream: create_error_toast("Validation failed: #{errors}"),
          status: :unprocessable_entity
      end
    end
  end

  def render_parameter_missing(exception)
    param_name = exception.param

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: "Missing required parameter: #{param_name}") }
      format.json { render json: {error: "Missing required parameter: #{param_name}"}, status: :bad_request }
      format.turbo_stream do
        render turbo_stream: create_error_toast("Missing required parameter: #{param_name}"),
          status: :bad_request
      end
    end
  end

  def render_duplicate_record(exception)
    # Extract a more user-friendly message from the SQL error if possible
    message = if exception.message.include?("UNIQUE constraint failed")
      "This record already exists"
    else
      "Duplicate entry - this record already exists"
    end

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: message) }
      format.json { render json: {error: message}, status: :conflict }
      format.turbo_stream do
        render turbo_stream: create_error_toast(message), status: :conflict
      end
    end
  end

  def render_invalid_reference(exception)
    message = "Cannot delete - this record is still being used elsewhere"

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: message) }
      format.json { render json: {error: message}, status: :conflict }
      format.turbo_stream do
        render turbo_stream: create_error_toast(message), status: :conflict
      end
    end
  end

  def render_database_error(exception)
    # Log the full exception for debugging
    Rails.logger.error "Database error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    message = Rails.env.production? ?
      "A database error occurred. Please try again." :
      "Database error: #{exception.message}"

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: message) }
      format.json { render json: {error: message}, status: :internal_server_error }
      format.turbo_stream do
        render turbo_stream: create_error_toast(message),
          status: :internal_server_error
      end
    end
  end
end
