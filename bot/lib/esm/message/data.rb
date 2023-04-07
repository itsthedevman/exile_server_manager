# frozen_string_literal: true

module ESM
  class Message
    class Data
      DATA_TYPES =
        YAML.safe_load(
          File.read(File.expand_path("./config/message/data_types.yml"))
        ).merge(
          YAML.safe_load(
            File.read(File.expand_path("./config/message/metadata_types.yml"))
          )
        ).deep_symbolize_keys.freeze

      TYPES = {
        any: {
          converter: lambda do |value|
            # Check if it's JSON like
            result = ESM::JSON.parse(value.to_s)
            return value if result.nil?

            # Check to see if its a hashmap
            possible_hashmap = ESM::Arma::HashMap.from(result)
            return result if possible_hashmap.nil?

            result
          end
        },
        array: {
          valid_classes: [Array],
          converter: ->(value) { value.to_a }
        },
        string: {
          valid_classes: [String],
          converter: ->(value) { value.to_s }
        },
        integer: {
          valid_classes: [Integer],
          converter: ->(value) { value.to_i }
        },
        hash: {
          valid_classes: [Hash],
          converter: ->(value) { value.to_h }
        },
        float: {
          valid_classes: [Float],
          converter: ->(value) { value.to_d }
        },
        boolean: {
          valid_classes: [TrueClass, FalseClass],
          converter: ->(value) { value.to_s == "true" }
        },
        hash_map: {
          valid_classes: [ESM::Arma::HashMap],
          converter: ->(value) { ESM::Arma::HashMap.from(value) }
        },
        date_time: {
          valid_classes: [::Time, DateTime],
          converter: ->(value) { ESM::Time.parse(value) }
        },
        date: {
          valid_classes: [Date],
          converter: ->(value) { ::Date.parse(value) }
        }
      }.freeze

      attr_reader :type, :content

      def initialize(type = :empty, content = nil)
        @type = type.to_sym
        @original_content = {}
        @content = {}
        return if type == :empty

        content =
          case content
          when OpenStruct
            content.table
          when Struct, ImmutableStruct
            content.to_h
          else
            content
          end

        return unless content.is_a?(Hash)

        content = sanitize_content(content)
        @original_content = content
        @content = content.to_istruct
      end

      def to_h(for_arma: false)
        hash = {type: type}

        convert_values = lambda do |value|
          case value
          when Numeric
            # Numbers have to be sent as Strings
            value.to_s
          when Hash, ESM::Arma::HashMap, ImmutableStruct
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
            (for_arma && type == :empty) ||
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
      def sanitize_content(inbound_content)
        inbound_content.deep_symbolize_keys!
        types_mapping = DATA_TYPES[@type]

        # Catches if DATA_TYPES does not have type defined
        if types_mapping.nil?
          raise ESM::Exception::InvalidMessage, "Failed to find #{self.class.name} type \"#{@type}\" in \"config/message/*_types.yml\""
        end

        types_mapping.each_with_object({}) do |(attribute_name, attribute_hash), output|
          # Check for missing required attributes
          if attribute_hash[:optional].blank? && !inbound_content.key?(attribute_name)
            raise ESM::Exception::InvalidMessage,
              "Missing required key \"#{attribute_name}\" for #{self.class.name} type \"#{@type}\""
          end

          # Not all items will be converted, it depends on the configs
          output[attribute_name] = convert(inbound_content[attribute_name], **attribute_hash)
        end
      end

      def convert(inbound_value, **attribute_hash)
        type = (attribute_hash[:type] || :any).to_sym

        # Handle if it can be nil or not
        can_be_nil = type == :any || attribute_hash[:optional]
        if inbound_value.nil? && !can_be_nil
          raise ESM::Exception::InvalidMessage,
            "Missing attribute \"#{attribute_name}\" for \"#{@type}\""
        end

        # This contains the conversion data
        type_data = retrieve_type_data(type)

        optional = attribute_hash[:optional] || false
        valid_classes = type_data[:valid_classes] || []

        # Check if converting is needed
        if (optional && inbound_value.nil?) || valid_classes.any? { |c| inbound_value.is_a?(c) }
          return inbound_value
        end

        converter = type_data[:converter] || -> {}
        result = converter.call(inbound_value)

        # Subtype only supports Array (as of right now)
        subtype = attribute_hash[:subtype]
        return result unless type == :array && subtype&.key?(:type)

        result.map { |v| convert(v, **subtype) }
      end

      def retrieve_type_data(type)
        type_data = TYPES[type]
        if type_data.nil?
          raise ESM::Exception::InvalidMessage, "\"#{type}\" was not defined in ESM::Message::Data::TYPES"
        end

        type_data
      end
    end
  end
end
