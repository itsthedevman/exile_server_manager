module ESM
  module Command
    class Base
      attr_writer :limit_to, :requires, :event

      # Returns a valid command string for execution.
      #
      # @example No arguments
      #   ESM::Command::SomeCommand.statement -> "!somecommand"
      # @example With arguments !argumentcommand <argument_1> <argument_2>
      #   ESM::Command::ArgumentCommand.statement(argument_1: "foo", argument_2: "bar") -> !argumentcommand foo bar
      def statement(**flags)
        # Can't use distinct here - 2020-03-10
        command_statement = "#{prefix}#{flags[:_use_alias] || name}"

        # !birb, !doggo, etc.
        return command_statement if @arguments.empty?

        # !whois <target> -> !whois #{flags[:target]} -> !whois 1234567890
        @arguments.map(&:name).each do |name|
          command_statement += " #{flags[name]}"
        end

        command_statement
      end

      alias_method :old_execute, :execute
      def execute(event, raise_error: true)
        old_execute(event)
      rescue => e
        handle_error(e, raise_error: raise_error)
      end
    end
  end
end
