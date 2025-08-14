# frozen_string_literal: true

module ESM
  module Color
    ALL = [
      BLUE = "#1e354d",
      RED = "#ce2d4e"
    ].freeze

    module Toast
      ALL = [
        RED = "#c62551",
        BLUE = "#3ed3fb",
        GREEN = "#9fde3a",
        YELLOW = "#deca39",
        ORANGE = "#c64a25",
        BURNT_ORANGE = "#7d2f00",
        PURPLE = "#793ade",
        LAVENDER = "#344d71",
        PINK = "#de3a9f",
        WHITE = "#ffffff",
        STEEL_GREEN = "#2f4858",
        BROWN = "#574143",
        SAGE = "#e9f6d0"
      ].freeze

      def self.to_h
        (constants(false) - [:ALL]).to_h { |c| [c.downcase, const_get(c)] }
      end
    end

    # Randomly select a color from the full color pool
    def self.random
      (ALL + ESM::Color::Toast::ALL).sample
    end
  end
end
