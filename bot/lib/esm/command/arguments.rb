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
        # This collects all of the invalid arguments together and sends one message instead of breaking at the first invalid argument
        invalid_arguments =
          templates.filter_map do |(name, template)|
            # Apply pre-defined transformations and then validate the content
            self[name] = template.transform_and_validate!(self[name], command_instance)

            nil
          rescue ESM::Exception::InvalidArgument => e
            self[name] = nil
            e.data
          end

        # All the arguments are valid
        return if invalid_arguments.empty?

        embed =
          ESM::Embed.build do |e|
            help_documentation = invalid_arguments.join_map("\n\n", &:help_documentation)

            help_usage = ESM::Command.get(:help).usage(
              with_args: true,
              arguments: {with: command_instance.usage(with_slash: false, with_args: false)}
            )

            argument_word = "argument".pluralize(invalid_arguments.size)

            e.title = "**Invalid #{argument_word}**"
            e.description = <<~STRING
              ```#{command_instance.usage(with_args: true, use_placeholders: true, arguments: self)}```
              **Please read the following and correct any errors before trying again.**

              **Missing #{argument_word}**
              #{help_documentation}

              For more information, use the following command:
              ```#{help_usage}```
            STRING

            e.add_field(
              name: I18n.t("commands.help.command.examples"),
              value: command_instance.examples
            )
          end

        raise ESM::Exception::CheckFailure, embed
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

          # self[server_id] = value from discord
          self[name] = values[argument.display_name]

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
