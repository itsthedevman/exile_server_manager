# frozen_string_literal: true

require "fast_jsonparser"

module ESM
  module JSON
    def self.parse(json)
      FastJsonparser.parse(json)
    rescue
      nil
    end

    def self.pretty_generate(json)
      json = parse(json) if json.is_a?(String)
      ::JSON.neat_generate(json, after_comma: 1, after_colon: 1, wrap: 95)
    end
  end
end
