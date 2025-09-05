# frozen_string_literal: true

module ToastHelper
  def create_toast(body, title: "", subtitle: "", color: nil)
    turbo_stream.append("toast-container") do
      concat(
        render_component(
          ToastComponent,
          title:, subtitle:, body:, color:
        )
      )
    end
  end

  def create_info_toast(*, title: "Info", **)
    create_toast(*, title:, **)
  end

  def create_success_toast(*, title: "Success", **)
    create_toast(*, title:, **)
  end

  def create_warn_toast(*, title: "Warn", **)
    create_toast(*, title:, **)
  end

  def create_error_toast(*, title: "Error", **)
    create_toast(*, title:, **)
  end
end
