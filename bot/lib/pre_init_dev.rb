# frozen_string_literal: true

return if !ESM.env.development?

require "active_record_query_trace"
require "pry"
require "colorize"

# Allows seeing the backtrace for queries
# Only use lines that pertain to ESM
ActiveRecordQueryTrace.level = :custom
ActiveRecordQueryTrace.backtrace_cleaner = lambda do |trace|
  trace.select { |line| line.match?("esm") }
end
ActiveRecordQueryTrace.enabled = false

# ActiveRecordQueryTrace requires Rails.root to be defined
module Rails
  def self.root
    File.expand_path(__dir__)
  end
end

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# ActiveRecord logging
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?
