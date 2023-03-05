# frozen_string_literal: true

module ESM
  class Message
    class Data
      MAPPING = YAML.safe_load(File.read(File.expand_path("./config/mapping.yml"))).stringify_keys.freeze
      ARRAY_REGEX = /array<(?<type>.+)>/i.freeze
      NIL_REGEX = /^\?(?<type>.+)/.freeze

      attr_reader :type, :content

      def initialize(type = "empty", content = nil)
        @type = type.to_s
        @original_content = {}
        @content = {}
        return if type == "empty"

        content =
          case content
          when OpenStruct
            content.table
          when Struct
            content.to_h
          else
            content
          end

        return unless content.is_a?(Hash)

        content = sanitize_content(content)
        @original_content = content
        @content = content.to_ostruct
      end

      def to_h(for_arma: false)
        hash = {type: type}

        convert_values = lambda do |value|
          case value
          when Numeric
            # Numbers have to be sent as Strings
            value.to_s
          when Hash, ESM::Arma::HashMap
            value.transform_values(&convert_values)
          when Array
            value.map(&convert_values)
          when OpenStruct, Struct
            value.table.symbolize_keys.transform_values(&convert_values)
          when DateTime, Time
            value.strftime("%FT%T%:z") # yyyy-mm-ddT00:00:00ZONE
          else
            value
          end
        end

        # This blocks the content key from being added to the hash
        #   which in turn keeps it from being included in the JSON that is sent to the server
        #   Bonus: Handles invalid data
        if !@original_content.is_a?(Hash) ||
            (for_arma && type == "empty") ||
            (for_arma && @original_content.blank?)
          return hash
        end

        hash[:content] = @original_content.transform_values(&convert_values)
        hash
      end

      private

      # Sanitizes the provided content in accordance to the data defined in config/mapping.yml
      # Sanitize also ensures the order of the content when exporting
      # @see config/mapping.yml for more information
      def sanitize_content(content)
        content.stringify_keys!
        mapping = MAPPING[@type]

        # Catches if MAPPINGS does not have type defined
        raise ESM::Exception::InvalidMessage, "Failed to find type \"#{@type}\" in \"config/mapping.yml\"" if mapping.nil?

        if (difference = mapping.keys - content.keys).any?
          raise ESM::Exception::InvalidMessage, "Unexpected keys found for #{self.class.to_s.downcase} \"#{@type}\" - #{difference}"
        end

        output = {}
        mapping.each do |attribute_name, attribute_type|
          entry = content[attribute_name]

          can_be_nil = attribute_type == "Any" || attribute_type.match?(NIL_REGEX)
          raise ESM::Exception::InvalidMessage, "\"#{attribute_name}\" is expected for message with data type of \"#{@type}\"" if entry.nil? && !can_be_nil

          # Some classes are not valid ruby classes and need converted
          klass =
            case attribute_type
            when "HashMap"
              ESM::Arma::HashMap
            when "Any", "Boolean", ARRAY_REGEX, NIL_REGEX
              NilClass # Always convert theses
            when "Decimal"
              BigDecimal
            else
              attribute_type.constantize
            end

          output[attribute_name] =
            if entry.is_a?(klass)
              entry
            else
              # Perform the conversion and replace the value
              convert_type(entry, into_type: attribute_type)
            end
        end

        output
      end

      def convert_type(value, into_type:)
        return value if value.class.to_s == into_type

        case into_type
        when "Any"
          result = ESM::JSON.parse(value.to_s)
          return value if result.nil?

          # Check to see if its a hashmap
          possible_hashmap = ESM::Arma::HashMap.from(result)
          return result if possible_hashmap.nil?

          result
        when ARRAY_REGEX
          match = into_type.match(ARRAY_REGEX)
          raise ESM::Exception::Error, "Failed to parse inner type from \"#{into_type}\"" if match.nil?

          # Convert the inner values to whatever type is configured
          value.to_a.map { |v| convert_type(v, into_type: match[:type]) }
        when NIL_REGEX
          return if value.nil?

          match = into_type.match(NIL_REGEX)
          raise ESM::Exception::Error, "Failed to parse inner type from \"#{into_type}\"" if match.nil?

          convert_type(value, into_type: match[:type])
        when "Array"
          value.to_a
        when "String"
          value.to_s
        when "Integer"
          value.to_i
        when "Hash"
          value.to_h
        when "Decimal"
          value.to_d
        when "Boolean"
          value.to_s == "true"
        when "HashMap"
          ESM::Arma::HashMap.from(value)
        when "DateTime"
          ESM::Time.parse(value)
        when "Date"
          ::Date.parse(value)
        else
          raise ESM::Exception::Error, "\"#{into_type}\" is an unsupported type"
        end
      end
    end
  end
end
