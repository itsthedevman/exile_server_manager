return unless Rails.env.development?

Rack::MiniProfiler.config.position = "bottom-left"
