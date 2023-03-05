# frozen_string_literal: true

module ESM
  module JSON
    def self.parse(json, as_ostruct: false)
      output = FastJsonparser.parse(json)
      return self.as_ostruct(output) if as_ostruct

      output
    rescue
      nil
    end

    # Converts a Hash or JSON string to a pretty formatted JSON string for printing to the console
    #
    # @param json [Hash, String] The data to format
    # @return [String] The prettified data to print
    def self.pretty_generate(json)
      json = parse(json) if json.is_a?(String)
      ::JSON.neat_generate(json, after_comma: 1, after_colon: 1, wrap: 95)
    end

    private_class_method def self.as_ostruct(input_hash)
      transform_value = lambda do |value|
        value =
          case value
          when Hash
            value = value.transform_values { |v| transform_value.call(v) }
            OpenStruct.new(**value)
          when Array
            value.map { |v| transform_value.call(v) }
          else
            value
          end

        return value
      end

      input_hash = input_hash.transform_values { |v| transform_value.call(v) }
      OpenStruct.new(**input_hash)
    end
  end
end
