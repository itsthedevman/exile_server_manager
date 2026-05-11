# frozen_string_literal: true

##
# Catches POSIX termination signals (INT, TERM, QUIT) and shuts the bot
# down cleanly: stops the Discord connection, then exits.
#
# Ruby's `Signal.trap` block runs in a *very* restricted context (no mutex
# acquisition, no most IO, no allocation that could deadlock the GC). To
# stay safe, the trap does the minimum possible: it `write_nonblock`s the
# signal name into a pipe. A dedicated thread reads the other end of the
# pipe and runs the real shutdown logic in a normal Ruby context.
#
# Started from {ESM.run!}; the test environment skips the install so
# RSpec can exit normally.
#
class SignalHandler
  include Singleton

  SIGNALS = %w[INT TERM QUIT]

  ##
  # Installs the signal traps and starts the dispatcher thread.
  #
  # @return [Thread] the dispatcher thread
  #
  def self.start
    instance.start
  end

  ##
  # @return [Thread] the dispatcher thread
  #
  def start
    @signal_read, @signal_write = IO.pipe

    SIGNALS.each do |signal|
      Signal.trap(signal) do
        @signal_write.write_nonblock("#{signal}\n")
      end
    end

    Thread.new do
      while (signal = @signal_read.gets&.strip)
        handle_signal(signal)
      end
    end
  end

  private

  def handle_signal(signal)
    puts "Handling #{signal} signal..."

    ESM.discord_bot&.stop

    exit
  end
end
