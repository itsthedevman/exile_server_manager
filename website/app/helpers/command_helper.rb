# frozen_string_literal: true

module CommandHelper
  include ArgumentFormatting

  def command_usage(command_name, arguments: {}, show_arguments: true)
    command = Command.all[command_name.to_sym]
    return command_name.to_s unless command

    if show_arguments && arguments.present?
      args_html = build_custom_arguments(command, arguments.with_indifferent_access)

      content_tag(:span, class: "command") do
        content_tag(:span, "#{command.usage} #{args_html}".html_safe)
      end
    elsif show_arguments
      render_component(CommandUsageDocsComponent, command: command)
    else
      content_tag(:span, class: "command") do
        content_tag(:span, command.usage)
      end
    end
  end

  def allowlist_roles(command)
    current_community.roles.map do |role|
      {
        value: role.id,
        label: role.name,
        selected: command.configuration.allowlisted_role_ids.include?(role.id)
      }
    end.to_json
  end

  private

  def build_custom_arguments(command, provided_arguments)
    command.arguments.join_map(" ") do |name, argument|
      value = provided_arguments[argument["name"]] || provided_arguments[argument["display_name"]]
      next unless value

      semantic_class = argument_semantic_class(name, argument)
      format_argument(argument["display_name"], "arg #{semantic_class}", value: value)
    end
  end
end
