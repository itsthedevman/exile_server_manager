# frozen_string_literal: true

class Timer
  attr_reader :started_at, :stopped_at

  #
  # Runs the provided block with a timer
  #
  # @return [Integer] The elapsed time in seconds
  #
  def self.time(&block)
    timer = new

    timer.start!
    yield
    timer.stop!

    timer.time_elapsed
  end

  def self.start!
    new.start!
  end

  def initialize
    @started_at = nil
    @stopped_at = nil
  end

  def start!
    @started_at ||= Time.current
    self
  end

  def stop!
    return self if @started_at.nil?

    @stopped_at ||= Time.current
    time_elapsed
  end

  def reset!
    @started_at = nil
    @stopped_at = nil
    self
  end

  def started?
    !started_at.nil?
  end

  def finished?
    !stopped_at.nil?
  end

  def time_elapsed
    return 0 if started_at.nil?

    (stopped_at || Time.current) - started_at
  end

  def to_h
    {
      started_at: started_at,
      stopped_at: stopped_at,
      time_elapsed: time_elapsed
    }
  end
end
