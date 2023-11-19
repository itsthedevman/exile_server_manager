# frozen_string_literal: true

timer = Timer.start!

require "active_record_query_trace"
require "awesome_print"

# Allows seeing the backtrace for queries
# Only use lines that pertain to ESM
ActiveRecordQueryTrace.enabled = ENV["TRACE"] == "true"
ActiveRecordQueryTrace.level = :custom
ActiveRecordQueryTrace.backtrace_cleaner = lambda do |trace|
  trace.select { |line| line.match?("esm") }
end

ESM.logger.level = Logger::TRACE

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# ActiveRecord logging
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?

info!("Completed in #{timer.stop!}s")
