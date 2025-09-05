# frozen_string_literal: true

class CommandExampleDocsComponent < ApplicationComponent
  include ArgumentFormatting

  def on_load(command:)
    @command = command
  end

  def call
    @command.examples.join_map do |example|
      <<~HTML
        <div class="border border-secondary rounded p-3 mb-3 bg-dark">
          <div class="mb-3 text-muted">#{Markdown.to_html(example["description"])}</div>
          <div class="bg-body rounded p-2 font-monospace">
            #{helpers.render_component CommandUsageDocsComponent, command: @command}
          </div>
        </div>
      HTML
    end.html_safe
  end
end
