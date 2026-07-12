# frozen_string_literal: true

module ApplicationHelper
  def render_component(klass, **locals, &block)
    component = klass.new(current_user:, &block).tap do |component|
      component.on_load(**locals) if component.respond_to?(:on_load)
    end

    render(component)
  end

  def link_to_tab(*, **args, &)
    link_to(*, args.merge(target: "_blank"), &)
  end

  def digest(data)
    Digest::SHA256.hexdigest(data)[0..24]
  end

  def poptabs(amount, inline: false)
    icon_classes = inline ? %w[poptab-icon-inline] : %w[ms-2 mb-2 align-text-bottom]

    safe_join([number_with_delimiter(amount), poptab_icon(classes: icon_classes)])
  end

  def poptab_icon(classes: [])
    url = image_path("poptab.png")

    content_tag(:span, "",
      class: class_names("poptab-icon", *classes),
      role: "img", "aria-label": "poptabs",
      style: "mask-image: url(#{url}); -webkit-mask-image: url(#{url});")
  end

  # Renders a model-formatted price string ("30 poptabs", "1,000 poptabs (5% tax
  # added)") with the poptab icon in place of the literal word. Uses the smaller
  # inline icon so it sits with the number rather than the larger money display.
  def poptab_price(text)
    number, _match, suffix = text.to_s.partition(/\s*poptabs\s*/)
    safe_join([number, poptab_icon(classes: %w[poptab-icon-inline]), (" #{suffix.strip}" if suffix.present?)].compact)
  end

  def nav_spacer
    safe_join([
      content_tag(:hr, nil, class: "hr.d-block.d-lg-none"),
      link_to("-", "", class: "nav-link disabled d-none d-lg-block")
    ])
  end
end
