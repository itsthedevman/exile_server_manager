# frozen_string_literal: true

module ServersHelper
  # TODO: Docs
  def server_manageable?(server)
    server.community.modifiable_by?(current_user)
  end

  # TODO: Docs
  def server_favorited?(server)
    current_user.server_favorites.exists?(server_id: server.id)
  end

  def render_setting(key, settings, &block)
    has_key = settings.has_key?(key)
    value = settings[key]
    default_value = ESM::ServerSetting::CONFIG_DEFAULTS[key].presence

    line =
      if has_key && value.present? && value != default_value
        if value.is_a?(Array)
          if value.empty?
            "#{key}: []"
          else
            "#{key}:\n#{value.map { |v| "- #{v.to_json}" }.join("\n")}"
          end
        else
          "#{key}: #{(value || "").to_json}"
        end
      else
        "# #{key}: #{(default_value || "").to_json}"
      end

    line.html_safe
  end
end
