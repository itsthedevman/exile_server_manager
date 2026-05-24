# frozen_string_literal: true

class CommandExampleDocsComponent < ApplicationComponent
  def on_load(command:)
    @command = command
  end

  def call
    @command.examples.join_map do |example|
      <<~HTML
        <div class="border border-secondary rounded p-3 mb-3 bg-dark">
          <div class="mb-3 text-muted">#{Markdown.to_html(example[:description])}</div>
          <div class="bg-body rounded p-2 font-monospace">
            #{example_usage(example)}
          </div>
        </div>
      HTML
    end.html_safe
  end

  private

  # Renders the usage with this example's argument values filled in
  # (e.g. `/help with:player commands`). Examples without arguments fall back to
  # the bare usage (`/help`).
  def example_usage(example)
    arguments = example[:arguments]

    if arguments.present?
      helpers.command_usage(@command.name, arguments:)
    else
      helpers.command_usage(@command.name, show_arguments: false)
    end
  end
end
