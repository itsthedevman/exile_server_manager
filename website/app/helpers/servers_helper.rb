# frozen_string_literal: true

module ServersHelper
  ##
  # Whether the current user may manage the given server, i.e. modify its owning community.
  #
  # @param server [ESM::Server]
  #
  # @return [Boolean]
  #
  def server_manageable?(server)
    server.community.modifiable_by?(current_user)
  end

  ##
  # Whether the current user has favorited the given server.
  #
  # @param server [ESM::Server]
  #
  # @return [Boolean]
  #
  def server_favorited?(server)
    current_user.server_favorites.exists?(server_id: server.id)
  end

  ##
  # The address a player joins on, as ip:port.
  #
  # @param server [ESM::Server]
  #
  # @return [String]
  #
  def server_address(server)
    "#{server.server_ip}:#{server.server_port}"
  end

  ##
  # How long until the server's next restart, or nothing when there is no countdown to give. The sidebar already says
  # whether the server is up, so a server that is down or one ESM has never seen start simply drops the line rather
  # than restating offline.
  #
  # @param server [ESM::Server]
  #
  # @return [String, nil]
  #
  def server_restart_countdown(server)
    return unless server.connected? && server.server_start_time?

    server.time_left_before_restart
  end

  ##
  # The server's mods grouped for display: required first, since those are what a player has to install before they
  # can connect at all. An empty group is dropped so a server with no optional mods shows no empty heading.
  #
  # @param server [ESM::Server]
  #
  # @return [Array<Datum>] each responds to #label and #mods
  #
  def server_mod_groups(server)
    mods = server.server_mods.sort_by { |mod| mod.mod_name.to_s.downcase }

    [
      Datum.new(label: "Required mods", mods: mods.select(&:mod_required?)),
      Datum.new(label: "Optional mods", mods: mods.reject(&:mod_required?))
    ].reject { |group| group.mods.empty? }
  end

  ##
  # One mod as a player reads it: its name, plus its version when the owner recorded one.
  #
  # @param mod [ESM::ServerMod]
  #
  # @return [String]
  #
  def server_mod_label(mod)
    [mod.mod_name, mod.mod_version].compact_blank.join(" ")
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
