# frozen_string_literal: true

module ESM
  module Command
    class Base
      # Returns a valid command string for execution.
      #
      # @example No arguments
      #   ESM::Command::SomeCommand.statement -> "!somecommand"
      # @example With arguments !argumentcommand <argument_1> <argument_2>
      #   ESM::Command::ArgumentCommand.statement(argument_1: "foo", argument_2: "bar") -> !argumentcommand foo bar
      def self.statement(**flags)
        command_statement = "#{ESM.bot.prefix}#{@name}"

        # !birb, !doggo, etc.
        return command_statement if @arguments.empty?

        # !whois <target> -> !whois #{flags[:target]} -> !whois 1234567890
        @arguments.map(&:name).each do |name|
          command_statement += " #{flags[name]}"
        end

        command_statement
      end

      def statement(**flags)
        self.class.statement(flags)
      end
    end
  end
end
