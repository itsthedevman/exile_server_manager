# frozen_string_literal: true

module DashboardHelper
  def channel_select_tag(name, channels, options = {})
    selected_channel_id = options.delete(:selected)
    include_blank = options.delete(:include_blank) { "Select a channel..." }

    channel_options = build_channel_options_with_separators(channels, selected_channel_id)

    select_tag(name, channel_options, {include_blank: include_blank}.merge(options))
  end

  private

  def build_channel_options_with_separators(channels, selected_id)
    return "".html_safe if channels.blank?

    channels.join_map do |(category, category_channels)|
      next if category_channels.blank?

      options = ""

      # Add a category separator if there's a category
      if category&.dig(:name)
        options += content_tag(
          :option,
          "--- #{category[:name]} ---",
          value: "",
          disabled: true,
          class: "text-muted fw-bold"
        )
      end

      # Add channels
      category_channels.each do |channel|
        channel_name = category&.dig(:name) ? "    #{channel[:name]}" : channel[:name]

        options += content_tag(
          :option,
          channel_name,
          value: channel[:id],
          selected: channel[:id] == selected_id
        )
      end

      options
    end.html_safe
  end
end
