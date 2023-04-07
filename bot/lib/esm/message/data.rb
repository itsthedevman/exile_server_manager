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
          class: Array,
          converter: ->(value) { value.to_a }
        },
        string: {
          class: String,
          converter: ->(value) { value.to_s }
        },
        integer: {
          class: Integer,
          converter: ->(value) { value.to_i }
        },
        hash: {
          class: Hash,
          converter: ->(value) { value.to_h }
        },
        float: {
          class: Float,
          converter: ->(value) { value.to_d }
        },
        boolean: {
          converter: ->(value) { value.to_s == "true" }
        },
        hash_map: {
          class: ESM::Arma::HashMap,
          converter: ->(value) { ESM::Arma::HashMap.from(value) }
        },
        date_time: {
          class: ::Time,
          converter: ->(value) { ESM::Time.parse(value) }
        },
        date: {
          class: ::Date,
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
          raise ESM::Exception::InvalidMessage, "Failed to find type \"#{@type}\" in \"config/message/*_types.yml\""
        end

        if (difference = types_mapping.keys - inbound_content.keys).any?
          raise ESM::Exception::InvalidMessage,
            "Unexpected keys found for #{self.class.to_s.downcase} \"#{@type}\" - #{difference}"
        end

        types_mapping.each_with_object({}) do |(attribute_name, attribute_hash), output|
          # Not all items will be converted, it depends on the configs
          output[attribute_name] = convert(inbound_content[attribute_name.to_sym], **attribute_hash)
        end
      end

      def convert(inbound_value, **attribute_hash)
        type = attribute_hash[:type] || :any

        # Handle if it can be nil or not
        can_be_nil = type == :any || attribute_hash[:optional]
        if inbound_value.nil? && !can_be_nil
          raise ESM::Exception::InvalidMessage,
            "Missing attribute \"#{attribute_name}\" for \"#{@type}\""
        end

        # This contains the conversion data
        type_data = retrieve_type_data(type)

        # NilClass will force it to be converted if needed
        into_class = type_data[:class] || NilClass
        return inbound_value if inbound_value.is_a?(into_class)

        converter = type_data[:converter] || -> {}
        result = converter.call(inbound_value)

        # Subtype only supports Array (as of right now)
        sub_type = attribute_hash[:subtype]
        return result unless type == :array && sub_type

        result.map { |v| convert(v, **sub_type) }
      end

      def retrieve_type_data(type)
        type_data = TYPES[type.to_sym]
        if type_data.nil?
          raise ESM::Exception::InvalidMessage, "\"#{type}\" was not defined in ESM::Message::Data::TYPES"
        end

        type_data
      end
    end
  end
end
