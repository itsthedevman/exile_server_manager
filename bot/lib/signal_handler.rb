# frozen_string_literal: true

class SignalHandler
  include Singleton

  SIGNALS = %w[INT TERM QUIT]

  def self.start
    instance.start
  end

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

    ESM.bot.stop

    exit
  end
end
