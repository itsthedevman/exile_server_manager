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
      ORANGE = "#c64a25"
      PURPLE = "#793ADE"
      PINK = "#DE3A9F"
      WHITE = "#FFFFFF"

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
