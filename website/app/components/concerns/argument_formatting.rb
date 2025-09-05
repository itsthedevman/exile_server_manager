# frozen_string_literal: true

module ArgumentFormatting
  def format_argument(name, color_class, value: nil, placeholder: nil, show_key: true)
    # Figure out what text to show and how to style it
    display_text = value.presence || (placeholder.present? ? "<#{placeholder}>" : nil)
    text_class = value.present? ? color_class : "text-muted"

    return "" if display_text.blank? && !show_key

    capture do
      if show_key
        concat content_tag(:span, name, class: color_class)
        concat content_tag(:span, ":", class: "text-secondary") if display_text.present?
      end
      concat content_tag(:span, display_text, class: text_class) if display_text.present?
    end
  end

  def argument_semantic_class(name, argument)
    display_name = argument["display_name"] || name

    # Identifiers - things that reference entities in the system
    return "identifier" if %w[
      server_id community_id territory_id
      on for from to in
    ].include?(display_name)

    # Targets - users/players to act upon
    return "target" if %w[
      target whom who
    ].include?(display_name)

    # Content - values, messages, data to process
    return "content" if %w[
      amount value money poptabs respect
      message reason description execute
      code_to_execute search_text
    ].include?(display_name)

    # Options - flags, modes, settings
    return "option" if %w[
      action type mode order_by broadcast_to
      cooldown_type notification_type
    ].include?(display_name)

    # Default fallback - most arguments are content-like
    "content"
  end
end
