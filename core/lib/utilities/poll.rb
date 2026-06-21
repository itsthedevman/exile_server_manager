# frozen_string_literal: true

#
# Polls a block at a fixed interval until it returns a truthy value or the
# timeout elapses. Useful for briefly waiting on out-of-process state to settle
# (e.g. a row another process writes) without committing to a full async flow.
#
# Uses a monotonic clock so a wall-clock adjustment can't stretch or collapse the
# window, and never sleeps past the deadline.
#
class Poll
  #
  # @param timeout [Numeric, ActiveSupport::Duration] how long to keep trying
  # @param every [Numeric, ActiveSupport::Duration] delay between attempts
  #
  # @yield the condition; polled until it returns truthy or time runs out
  #
  # @return [Object, nil] the block's truthy value, or nil if it never became
  #   truthy before the timeout
  #
  # @example Wait up to a second for a command to settle
  #   Poll.until(timeout: 1.second, every: 100.milliseconds) { command.reload.settled? }
  #
  def self.until(timeout:, every:, &condition)
    deadline = now + timeout.to_f
    interval = every.to_f

    loop do
      result = condition.call
      return result if result

      remaining = deadline - now
      return nil if remaining <= 0

      sleep(interval.clamp(0, remaining))
    end
  end

  def self.now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  private_class_method :now
end
