# frozen_string_literal: true

module ESM
  module Command
    class Arguments < Hash
      attr_reader :templates, :command_instance, :display_name_mapping

      def initialize(command = nil, templates: {}, values: {})
        @command_instance = command
        @templates = templates.symbolize_keys

        # Map the display name to the name itself
        @display_name_mapping = templates.values.each_with_object({}) { |a, hash| hash[a.display_name] = a.name }

        prepare(values.symbolize_keys)
      end

      def validate!
        # This collects all of the invalid arguments together and sends one message instead of breaking
        # at the first invalid argument
        invalid_arguments =
          templates.filter_map do |(name, template)|
            # Apply pre-defined transformations and then validate the content
            self[name] = template.transform_and_validate!(self[name], command_instance)

            nil
          rescue ESM::Exception::InvalidArgument => e
            # Capture what the user actually sent before unsetting it, so the error can echo their input back.
            invalid_value = self[name]
            self[name] = nil

            {argument: e.data, value: invalid_value}
          end

        raise Exception::InvalidArguments.new(invalid_arguments, command_instance) if invalid_arguments.size > 0
      end

      def inspect
        ESM::JSON.pretty_generate(
          values: self,
          command: command_instance&.command_name,
          templates: templates.map(&:to_h)
        )
      end

      def with_templates
        each_with_object({}) do |(name, value), hash|
          hash[name] = [templates[name], value]
        end
      end

      def template(name)
        name = name.to_sym
        mapping = @display_name_mapping[name] || name

        templates[mapping]
      end

      ###
      # Allows referencing arguments that may not exist on the current command, but does on others
      def method_missing(method_name, *arguments, &block)
        self[method_name.to_sym]
      end

      def respond_to_missing?(method_name, _include_private = false)
        key?(method_name.to_sym) || super
      end
      #
      ###

      private

      def prepare(values)
        return if templates.empty?

        templates.values.each do |argument|
          name = argument.name

          # Discord sends the display name ("on"); the website and request paths seed the argument's own
          # name ("server_id"). Accept either so every origin populates the same argument.
          self[name] = values[argument.display_name] || values[name]

          # self.server_id
          define_method(name) { self[name] }

          # self.for #=> server_id
          define_method(argument.display_name) { self[name] }

          # self.server_id = value
          define_method(:"#{name}=") { |value| self[name] = value }
        end
      end
    end
  end
end
