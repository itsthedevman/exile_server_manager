# frozen_string_literal: true

module ESM
  module Arma
    class HashMap < ActiveSupport::HashWithIndifferentAccess
      # TODO: Docs (redo)
      # @param input [String, Array, Hash, OpenStruct] The data to be converted. If a String, data must be array pairs
      def self.from(input)
        hash_map = new
        return hash_map if input.blank?

        hash_map.from(input)
      rescue
        nil
      end

      # TODO: Docs
      def initialize(data = {})
        super
        return if data.blank?

        from(data)
      end

      # TODO: Docs
      def from(input)
        hash = normalize(input)
        merge!(hash)

        self
      end

      # TODO: Docs
      def to_a
        convert_value =
          lambda do |value|
            case value
            when Array
              value.map { |v| convert_value.call(v) }
            when Hash, ActiveSupport::HashWithIndifferentAccess
              value.map do |key, value|
                [convert_value.call(key), convert_value.call(value)]
              end
            when Symbol
              value.to_s
            else
              value
            end
          end

        map { |key, value| [key, convert_value.call(value)] }
      end

      # TODO: Docs
      def to_json(*)
        ::JSON.generate(to_a, *)
      end

      alias_method :to_s, :to_json

      delegate :to_ostruct, :to_datum, to: :to_h
      delegate_missing_to :to_h

      private

      # The parameters sent over by Arma can be in a SimpleArray format. This will convert the value if need be.
      # Parameters can be of type:
      def normalize(input)
        case input
        when OpenStruct, Struct, Hash, ActiveSupport::HashWithIndifferentAccess
          input = input.to_h
          return if input.nil?

          input.transform_keys { |k| normalize(k) }
          input.transform_values { |v| normalize(v) }
        when Array, String
          # This will attempt to parse a string for json
          possible_hash_map =
            if input.is_a?(String)
              input.gsub("\"\"", "\"") # Handle arma string escape
                .gsub("<br/>", "\\n") # Handle <br/>
                .gsub("<br />", "\\n") # Handle <br />
                .gsub("<br></br>", "\\n") # Handle <br></br>
                .parse_json
            else
              input
            end

          if valid_hash_structure?(possible_hash_map)
            possible_hash_map.each_with_object({}) do |(key, value), obj|
              obj[normalize(key)] = normalize(value)
            end
          elsif possible_hash_map.is_a?(Array)
            possible_hash_map.map { |i| normalize(i) }
          else
            input
          end
        when Symbol
          input.to_s
        else
          input
        end
      end

      # Checks if the array is set up to be able to be converted to a hash
      # The input must be an array and in the format of [[key, value], [key, value]]
      #
      # Shape alone cannot prove an array is a hashmap. Arma flattens a hashmap and a list of pairs to the same bytes,
      # so `[[uid_a, uid_b]]` reads as either one. A repeated key does prove it is not a hashmap though, and
      # converting one anyway silently keeps only the last entry.
      def valid_hash_structure?(input)
        return false unless input.is_a?(Array)
        return false unless input.all? { |pair| pair.is_a?(Array) && pair.size == 2 && pair.first.is_a?(String) }

        keys = input.map(&:first)
        keys.size == keys.uniq.size
      end
    end
  end
end
