# frozen_string_literal: true

#
# A Concurrent::TimerTask whose work can't silently vanish.
#
# Concurrent::TimerTask only ever surfaces a StandardError: its internal SafeTaskExecutor rescues
# StandardError, so anything outside that tree (SystemStackError, NoMemoryError, ...) escapes before
# the observer notification runs and the executor pool drops it without a trace.
#
module ESM
  class TimerTask
    #
    # Builds and immediately starts the timer, mirroring Concurrent::TimerTask.execute.
    #
    # @param options [Hash] forwarded to Concurrent::TimerTask (e.g. +execution_interval:+, +run_now:+)
    #
    # @yield the work to run each interval; any raised error is logged and swallowed, never propagated
    #
    # @return [Concurrent::TimerTask]
    #
    def self.execute(**options, &task)
      Concurrent::TimerTask.execute(**options) do
        task.call
      rescue ::Exception => e # standard:disable Lint/RescueException
        ESM.logger.error!(error: e)
      end
    end
  end
end
