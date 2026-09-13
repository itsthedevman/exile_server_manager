# frozen_string_literal: true

module ErrorsHelper
  # 400 and 500 double as the copy for any status in their class that has none of its own
  ERROR_PAGES = {
    400 => {
      icon: "bi-exclamation-triangle",
      message: "That request couldn't be completed. Check the address and try again."
    },
    404 => {
      icon: "bi-search",
      message: "The page you're looking for doesn't exist or has been moved."
    },
    422 => {
      icon: "bi-arrow-clockwise",
      message: "That change was rejected. If this page was open for a while, refresh it and try again."
    },
    500 => {
      icon: "bi-bug",
      message: "Something went wrong on our end. Please try again in a moment."
    }
  }.freeze

  def error_page_title(status)
    "#{status} - #{Rack::Utils::HTTP_STATUS_CODES.fetch(status, "Error")}"
  end

  def error_page_icon(status)
    error_page(status)[:icon]
  end

  def error_page_message(status)
    error_page(status)[:message]
  end

  def error_page_help_prompt(status)
    server_error?(status) ? "If this keeps happening" : "If you believe this is an error"
  end

  private

  def error_page(status)
    ERROR_PAGES.fetch(status) { ERROR_PAGES.fetch(server_error?(status) ? 500 : 400) }
  end

  def server_error?(status)
    status >= 500
  end
end
