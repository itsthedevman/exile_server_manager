# frozen_string_literal: true

class LogsController < ApplicationController
  def show
    current_community = ESM::Community.find_by(public_id: params[:community_community_id])
    not_found! if current_community.nil?

    log = ESM::Log.includes(:log_entries, :server, :user)
      .active
      .find_by(public_id: params[:log_id])

    not_found! if log.nil?

    # Auto select the first log
    params[:file_id] = log.log_entries.first.public_id if params[:file_id].blank?

    render locals: {
      current_community:,
      log:
    }
  end
end
