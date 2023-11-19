# frozen_string_literal: true

module ESM
  module Color
    BLUE = "#1E354D"
    RED = "#CE2D4E"

    module Toast
      RED = "#C62551"
      BLUE = "#3ED3FB"
      GREEN = "#9FDE3A"
      YELLOW = "#DECA39"
      ORANGE = "#C64A25"
      BURNT_ORANGE = "#7D2F00"
      PURPLE = "#793ADE"
      LAVENDER = "#344D71"
      PINK = "#DE3A9F"
      WHITE = "#FFFFFF"
      STEEL_GREEN = "#2F4858"
      BROWN = "#574143"
      SAGE = "#E9F6D0"

      def self.colors
        constants(false).map { |c| const_get(c) }.select { |c| c.is_a?(String) }
      end
    end

    def self.colors
      constants(false).map { |c| const_get(c) }.select { |c| c.is_a?(String) }
    end

    # Randomly select a color from the full color pool
    def self.random
      (colors + ESM::Color::Toast.colors).sample(1).first
    end
  end
end
