# frozen_string_literal: true

module ESM
  class Message
    class Data < OpenStruct
      def initialize(**args)
        super(args.transform_values { |v| transform(v) })
      end

      private

      def transform(value)
        case value
        when String
          value.gsub(%r{<br\s*/?>(?:</br>)?}, "\n")
        when Array
          value.map { |v| transform(v) }
        when Hash
          value.transform_values { |v| transform(v) }
        else
          value
        end
      end
    end
  end
end
