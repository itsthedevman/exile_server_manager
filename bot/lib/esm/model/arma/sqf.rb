# frozen_string_literal: true

module ESM
  module Arma
    class Sqf
      def self.minify(code)
        [
          [/\s*;\s*/, ";"], [/\s*:\s*/, ":"], [/\s*,\s*/, ","], [/\s*\[\s*/, "["],
          [/\s*\]\s*/, "]"], [/\s*\(\s*/, "("], [/\s*\)\s*/, ")"], [/\s*-\s*/, "-"],
          [/\s*\+\s*/, "+"], [%r{\s*/\s*}, "/"], [/\s*\*\s*/, "*"], [/\s*%\s*/, "%"],
          [/\s*=\s*/, "="], [/\s*!\s*/, "!"], [/\s*>\s*/, ">"], [/\s*<\s*/, "<"],
          [/\s*>>\s*/, ">>"], [/\s*&&\s*/, "&&"], [/\s*\|\|\s*/, "||"], [/\s*\}\s*/, "}"],
          [/\s*\{\s*/, "{"], [/\s+/, " "], [/\n+/, ""], [/\r+/, ""], [/\t+/, ""]
        ].each do |group|
          code = code.gsub(group.first, group.second)
        end

        code
      end
    end
  end
end
