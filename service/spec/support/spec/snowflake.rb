# frozen_string_literal: true

module Spec
  #
  # Generator for unique fake Discord snowflakes used as IDs across the
  # test world (users, servers, channels, roles, members).
  #
  # Real Discord snowflakes are 17-20 digit timestamps. We reserve a base above any plausible real
  # value so a fake ID is recognisable at a glance in logs and assertions.
  #
  module Snowflake
    BASE = 9_000_000_000_000_000_000

    class << self
      #
      # Return the next unique snowflake as a String.
      #
      # @return [String] a snowflake-shaped numeric string, monotonically increasing within the process
      #
      def next
        @counter ||= 0
        @counter += 1
        (BASE + @counter).to_s
      end

      #
      # Reset the counter back to zero.
      #
      # Specs that depend on a deterministic ID across runs (rare) can call
      # this from a `before` hook. The around hook in spec_helper does NOT
      # call this - IDs grow monotonically across the suite.
      #
      def reset!
        @counter = 0
      end
    end
  end
end
