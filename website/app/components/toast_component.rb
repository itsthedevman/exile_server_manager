# frozen_string_literal: true

class ToastComponent < ApplicationComponent
  COLORS = [
    :red, :blue, :green, :yellow,
    :success, :info, :warn, :error,
    :alert, :notice
  ].freeze

  attr_reader :title, :subtitle, :body

  def on_load(title: nil, subtitle: nil, body: nil, color: nil)
    @title = title
    @subtitle = subtitle
    @body = body
    @color = color

    if color && COLORS.exclude?(color.to_sym)
      raise ArgumentError,
        "Invalid color provided to toast. Got #{color}, expected one of #{COLORS}"
    end
  end

  def color_class
    color = @color || color_from_title
    "toast-#{color}" if color
  end

  private

  def color_from_title
    # notice will use grey
    case title.downcase
    when "success"
      :green
    when "alert", "warn"
      :yellow
    when "error"
      :red
    when "info", "notice"
      :blue
    end
  end
end
