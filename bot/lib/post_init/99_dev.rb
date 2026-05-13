# frozen_string_literal: true

#
# Development-only setup: AR query backtraces, verbose ESM logging, and
# awesome_print loaded for nicer console output. Top-level `return` exits
# the require early in any non-development environment.
#

return unless ESM.env.development?

require "active_record_query_trace"
require "awesome_print"

# Shows the originating call site for every AR query, filtered to ESM
# code so the output doesn't drown in gem internals. Gated behind `TRACE=true`
# because the backtrace lookup is expensive enough to matter at dev volume.
ActiveRecordQueryTrace.enabled = ENV["TRACE"] == "true"
ActiveRecordQueryTrace.level = :custom
ActiveRecordQueryTrace.backtrace_cleaner = lambda do |trace|
  trace.select { |line| line.match?("esm") }
end

ESM.logger.level = Logger::TRACE

# discordrb's debug stream is extremely noisy and rarely useful even in dev.
Discordrb::LOGGER.debug = false

ActiveRecord::Base.logger = ESM.logger
