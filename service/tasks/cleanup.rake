# frozen_string_literal: true

namespace :cleanup do
  desc "Delete expired logs and their associated log entries"
  task expired_logs: :environment do
    puts "Starting cleanup of expired logs..."

    start_time = Time.current

    # Find all expired logs
    expired_logs = ESM::Log.where("expires_at < ?", Time.current)
    expired_count = expired_logs.count

    if expired_count.zero?
      puts "No expired logs found. Everything's clean!"
      return
    end

    puts "Found #{expired_count} expired log(s) to clean up"

    # Get the count of log entries that will be deleted
    log_entry_count = ESM::LogEntry.where(log_id: expired_logs.select(:id)).count
    puts "This will also remove #{log_entry_count} associated log entries"

    # Use a transaction to ensure consistency
    ActiveRecord::Base.transaction do
      # Delete log entries first (foreign key constraint)
      deleted_entries = ESM::LogEntry.where(log_id: expired_logs.select(:id)).delete_all
      puts "Deleted #{deleted_entries} log entries"

      # Then delete the logs
      deleted_logs = expired_logs.delete_all
      puts "Deleted #{deleted_logs} expired logs"
    end

    duration = Time.current - start_time
    puts "Cleanup completed in #{duration.round(2)} seconds"
  end

  desc "Show stats about expired logs without deleting them"
  task check_expired_logs: :environment do
    puts "Checking for expired logs..."

    expired_logs = ESM::Log.where("expires_at < ?", Time.current)
    expired_count = expired_logs.count

    if expired_count.zero?
      puts "No expired logs found!"
      next
    end

    log_entry_count = ESM::LogEntry.where(log_id: expired_logs.select(:id)).count

    puts "Expired logs summary:"
    puts "   - #{expired_count} expired log(s)"
    puts "   - #{log_entry_count} log entries to be removed"

    # Show oldest expired log
    oldest = expired_logs.order(:expires_at).first
    if oldest
      puts "   - Oldest expired: #{oldest.expires_at.strftime("%Y-%m-%d %H:%M:%S")}"
    end
  end
end
