# frozen_string_literal: true

module ESM
  module Command
    class Argument
      class Parser
        attr_reader :match, :argument

        delegate :regex, :preserve_case?, :type, :default, to: :@argument

        def initialize(argument)
          @argument = argument
        end

        #
        # Applies the argument regex against the message and attempts to extract the value
        #
        # @return [Array(String, (Any | Nil))] Returns [matched text, parsed and converted text]
        #
        def parse(message)
          message = message.strip

          # Take in the message and try to match the regex to the message
          match_object = regex.match(message)
          @match, value = match_object&.values_at(0, 1)

          value = extract_value_or_default(value)

          [@match, cast_value_type(value)]
        end

        private

        def cast_value_type(value)
          return value if type == :string

          case type
          when :integer
            value.to_i
          when :float
            value.to_f
          when :json
            ESM::JSON.parse(value)
          when :symbol
            value.to_sym
          else
            value
          end
        rescue
          value
        end

        def extract_value_or_default(match)
          # There is a match and if we don't want to preserve the case, convert it to lowercase
          return preserve_case? ? match.strip : match.downcase.strip if match.present?

          # No default, just return nil
          return if default.blank?

          # Return the default
          default
        end
      end
    end
  end
end
