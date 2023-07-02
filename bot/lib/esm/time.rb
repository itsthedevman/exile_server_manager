# frozen_string_literal: true

module ESM
  class Time
    include ActionView::Helpers::DateHelper
    include ActiveSupport::Inflector

    module Format
      TIME = "%F at %r UTC"
      DATE = "%F"
    end

    class Timer
      attr_reader :started_at, :stopped_at

      def initialize
        @started_at = nil
        @stopped_at = nil
      end

      def start!
        @started_at ||= Time.current
      end

      def stop!
        return if @started_at.nil?

        @stopped_at ||= Time.current
      end

      def reset!
        @started_at = nil
        @stopped_at = nil
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

    def self.distance_of_time_in_words(to_time, from_time: ESM::Time.current, precise: true)
      distance = new.distance_of_time_in_words(from_time.utc, to_time.utc, include_seconds: precise)
      singularize(distance)
    end

    def self.singularize(distance)
      # DOTIW doesn't singularize the single types. This converts 1 seconds -> 1 second; 1 minutes -> 1 minute, etc.
      distance.gsub(/(?<!\d)1 (?:seconds|minutes|hours|days|weeks|months|years)/i, &:singularize)
    end

    # Parses a stringed time as UTC time
    def self.parse(time)
      return time if time.is_a?(ActiveSupport::TimeWithZone)

      ::Time.find_zone("UTC").parse(time)
    end

    def self.current
      ::Time.find_zone("UTC").now
    end

    def self.now
      ::Time.now
    end
  end
end
