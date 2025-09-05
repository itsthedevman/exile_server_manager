# frozen_string_literal: true

module StimulusHelper
  def stimulus_event_action_string(event:, from:, to:, method:, global: true)
    action = "#{from}:#{event}"
    action += "@window" if global

    "#{action}->#{to}##{method}"
  end
end
