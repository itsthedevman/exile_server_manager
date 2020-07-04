# frozen_string_literal: true

module ESM
  module Command
    class Argument
      class Parser
        attr_reader :original, :argument
        attr_accessor :value

        def initialize(argument, message)
          @argument = argument
          @message = message.strip
        end

        def parse!
          # Take in the message and try to match the regex to the message
          match_object = @argument.regex.match(@message)
          return if match_object.nil?

          ESM.logger.debug("#{self.class}##{__method__}") { match_object.to_a }
          @original = match_object[0]
          @match = match_object[1]

          @value = cast_value_type(extract_value_or_default)

          self
        end

        private

        def cast_value_type(value)
          return value if @argument.type == :string

          begin
            case @argument.type
            when :integer
              value.to_i
            when :float
              value.to_f
            when :json
              JSON.parse(value)
            when :symbol
              value.to_sym
            else
              value
            end
          rescue StandardError
            value
          end
        end

        def extract_value_or_default
          # There is a match and if we don't want to preserve the case, convert it to lowercase
          return @argument.preserve_case? ? @match.strip : @match.downcase.strip if @match.present?

          # No default, just return nil
          return if @argument.default.blank?

          # Return the default
          @argument.default
        end
      end
    end
  end
end
