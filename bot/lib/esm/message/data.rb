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

      RUBY_TYPE_LOOKUP = {
        Array => :array,
        Date => :date,
        DateTime => :date_time,
        ESM::Arma::HashMap => :hash_map,
        FalseClass => :boolean,
        Float => :float,
        Hash => :hash,
        ImmutableStruct => :struct,
        Integer => :integer,
        Numeric => :float,
        OpenStruct => :struct,
        String => :string,
        Struct => :struct,
        Symbol => :string,
        ::Time => :date_time,
        TrueClass => :boolean
      }.freeze

      TYPES = {
        any: {
          into_ruby: lambda do |value|
            # Check if it's JSON like
            result = ESM::JSON.parse(value.to_s)
            return value if result.nil?

            # Check to see if its a hashmap
            possible_hashmap = ESM::Arma::HashMap.from(result)
            return result if possible_hashmap.nil?

            result
          end,
          into_arma: ->(value) { value }
        },
        array: {
          valid_classes: [Array],
          into_ruby: ->(value) { value.to_a },
          into_arma: ->(value) { value.map { |v| convert_into_arma(v) } }
        },
        boolean: {
          valid_classes: [TrueClass, FalseClass],
          into_ruby: ->(value) { value.to_s == "true" }
        },
        date: {
          valid_classes: [Date],
          into_ruby: ->(value) { ::Date.parse(value) },
          into_arma: ->(value) { value.strftime("%F") }
        },
        date_time: {
          valid_classes: [DateTime, ::Time],
          into_ruby: ->(value) { ESM::Time.parse(value) },
          into_arma: ->(value) { value.strftime("%FT%T%:z") } # yyyy-mm-ddT00:00:00ZONE
        },
        float: {
          valid_classes: [Float],
          into_ruby: ->(value) { value.to_d },
          into_arma: ->(value) { value.to_s }  # Numbers have to be sent as Strings
        },
        hash: {
          valid_classes: [Hash],
          into_ruby: ->(value) { value.to_h },
          into_arma: ->(value) { value.transform_values { |v| convert_into_arma(v) } }
        },
        hash_map: {
          valid_classes: [ESM::Arma::HashMap],
          into_ruby: ->(value) { ESM::Arma::HashMap.from(value) },
          into_arma: ->(value) { value.to_h.transform_values { |v| convert_into_arma(v) } }
        },
        integer: {
          valid_classes: [Integer],
          into_ruby: ->(value) { value.to_i },
          into_arma: ->(value) { value.to_s } # Numbers have to be sent as Strings
        },
        string: {
          valid_classes: [String],
          into_ruby: ->(value) { value.to_s },
          into_arma: ->(value) { value.to_s } # Symbol uses this as well
        },
        struct: {
          valid_classes: [ImmutableStruct, Struct, OpenStruct],
          into_ruby: ->(value) { value.to_h.to_istruct },
          into_arma: ->(value) { value.to_h.transform_values { |v| convert_into_arma(v) } }
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

        content = sanitize_inbound_content(content)
        @original_content = content
        @content = content.to_istruct
      end

      def to_h(for_arma: false)
        hash = {type: type}

        # This blocks the content key from being added to the hash
        #   which in turn keeps it from being included in the JSON that is sent to the server
        #   Bonus: Handles invalid data
        if !@original_content.is_a?(Hash) ||
            (for_arma && type == :empty) ||
            (for_arma && @original_content.blank?)
          return hash
        end

        hash[:content] = @original_content.transform_values { |v| convert_into_arma(v) }
        hash
      end

      private

      def retrieve_type_data(type)
        type_data = TYPES[type]
        if type_data.nil?
          raise ESM::Exception::InvalidMessage, "\"#{type}\" was not defined in ESM::Message::Data::TYPES"
        end

        type_data
      end

      # Sanitizes the provided content in accordance to the data defined in config/mapping.yml
      # Sanitize also ensures the order of the content when exporting
      # @see config/mapping.yml for more information
      def sanitize_inbound_content(inbound_content)
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
          output[attribute_name] = convert_into_ruby(inbound_content[attribute_name], **attribute_hash)
        end
      end

      def convert_into_ruby(inbound_value, **attribute_hash)
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

        into_ruby = type_data[:into_ruby] || ->(value) { value }
        result = into_ruby.call(inbound_value)

        # Subtype only supports Array (as of right now)
        subtype = attribute_hash[:subtype]
        return result unless type == :array && subtype&.key?(:type)

        result.map { |v| convert_into_ruby(v, **subtype) }
      end

      def convert_into_arma(inbound_value)
        convert_to_type = RUBY_TYPE_LOOKUP[inbound_value.class] || :any
        type_data = retrieve_type_data(convert_to_type)

        into_arma = type_data[:into_arma] || ->(value) { value }
        instance_exec(inbound_value, &into_arma)
      end
    end
  end
end
