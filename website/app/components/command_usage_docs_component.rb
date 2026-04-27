# frozen_string_literal: true

class CommandUsageDocsComponent < ApplicationComponent
  include ArgumentFormatting

  def on_load(command:)
    @command = command
  end

  def call
    arguments =
      @command.arguments.join_map(" ") do |name, argument|
        semantic_class = argument_semantic_class(name, argument)

        format_argument(
          argument["display_name"],
          "arg #{semantic_class}",
          placeholder: argument["placeholder"]
        )
      end

    content_tag(:span, "#{@command.usage} #{arguments}".html_safe, class: "command")
  end
end
