# frozen_string_literal: true

module ESM
  module Color
    ALL = [
      BLUE = "#1E354D",
      RED = "#CE2D4E"
    ].freeze

    module Toast
      ALL = [
        RED = "#C62551",
        BLUE = "#3ED3FB",
        GREEN = "#9FDE3A",
        YELLOW = "#DECA39",
        ORANGE = "#C64A25",
        BURNT_ORANGE = "#7D2F00",
        PURPLE = "#793ADE",
        LAVENDER = "#344D71",
        PINK = "#DE3A9F",
        WHITE = "#FFFFFF",
        STEEL_GREEN = "#2F4858",
        BROWN = "#574143",
        SAGE = "#E9F6D0"
      ].freeze

      def self.to_h
        (constants(false) - [:ALL]).to_h { |c| [c.downcase, const_get(c)] }
      end
    end

    # Randomly select a color from the full color pool
    def self.random
      (ALL + ESM::Color::Toast::ALL).sample.first
    end
  end
end
