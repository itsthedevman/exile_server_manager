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

  def poptabs(amount)
    url = image_path("poptab.png")

    icon = content_tag(:span, "",
      class: "poptab-icon ms-2 mb-2 align-text-bottom",
      role: "img", "aria-label": "poptabs",
      style: "mask-image: url(#{url}); -webkit-mask-image: url(#{url});")

    safe_join([number_with_delimiter(amount), icon])
  end

  def nav_spacer
    safe_join([
      content_tag(:hr, nil, class: "hr.d-block.d-lg-none"),
      link_to("-", "", class: "nav-link disabled d-none d-lg-block")
    ])
  end
end
