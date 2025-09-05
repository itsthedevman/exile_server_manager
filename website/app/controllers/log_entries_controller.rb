# frozen_string_literal: true

class LogEntriesController < ApplicationController
  def show
    log_entry = ESM::LogEntry.includes(:log).find_by(public_id: params[:entry_id])
    not_found! if log_entry.nil?

    render locals: {
      log_entry:,
      log: log_entry.log
    }
  end
end
