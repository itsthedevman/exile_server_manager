# frozen_string_literal: true

class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token

  before_action :authenticate_api_token!
  before_action :log_api_request

  private

  def authenticate_api_token!
    bearer_token = extract_bearer_token

    if bearer_token.blank? || bearer_token.size != 32
      unauthorized!("Invalid or missing API token")
    end

    @api_token = ESM::ApiToken.where(token: bearer_token, active: true).first
    unauthorized!("Invalid API token") if @api_token.nil?
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"]
    return if auth_header.blank?

    auth_header.match(/^Bearer (.+)$/i)&.captures&.first
  end

  def unauthorized!(message = "Unauthorized")
    raise Exceptions::UnauthorizedError, message
  end

  def bad_request!(message = "Bad request")
    raise Exceptions::BadRequestError, message
  end

  def payload_too_large!(message = "Payload too large")
    raise Exceptions::PayloadTooLargeError, message
  end

  def log_api_request
    api_logger.info({
      token_comment: @api_token.comment,
      client_ip: request.client_ip,
      remote_ip: request.remote_ip,
      url: request.url,
      method: request.method,
      params: filtered_params
    }.to_json)
  end

  def filtered_params
    params.except(:controller, :action).permit!.to_h
  end

  def api_logger
    @api_logger ||= Logger.new(Rails.root.join("log", "api.log"), "daily")
  end
end
