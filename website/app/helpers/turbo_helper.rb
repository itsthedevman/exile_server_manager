# frozen_string_literal: true

module TurboHelper
  def turbo_frame(id, **args, &block)
    turbo_frame_tag("#{id}_frame", **args, &block)
  end

  alias_method :update_turbo_frame, :turbo_frame

  def update_turbo_modal(id, &block)
    turbo_frame_tag("#{id}_frame") do
      yield

      concat content_tag(:div, nil, data: {trigger: "modal:show:##{id}"})
    end
  end

  def show_modal(selector)
    turbo_stream.append("main-container") do
      content_tag(:div, nil, data: {trigger: "modal:show:#{selector}"})
    end
  end

  def hide_modal(selector)
    turbo_stream.append("main-container") do
      content_tag(:div, nil, data: {trigger: "modal:hide:#{selector}"})
    end
  end
end
