# frozen_string_literal: true

class CommandArgumentDocsComponent < ApplicationComponent
  include ArgumentFormatting

  def on_load(command:)
    @command = command
  end

  def call
    arguments_size = @command.arguments.size

    arguments =
      @command.arguments.join_map(with_index: true) do |(name, argument), index|
        semantic_class = argument_semantic_class(name, argument)
        bottom_margin = (arguments_size == (index + 1)) ? "" : "mb-3"

        <<~HTML
          <div class="p-3 bg-dark border border-secondary rounded #{bottom_margin}">
            <div class="mb-2">
              <span class="arg #{semantic_class} fs-6">#{argument["display_name"]}</span>
            </div>
            <div class="text-light">
              #{Markdown.to_html(argument["description"])}
              #{"<br>#{Markdown.to_html(argument["description_extra"])}" if argument["description_extra"].present?}
            </div>
          </div>
        HTML
      end

    arguments.html_safe
  end
end
