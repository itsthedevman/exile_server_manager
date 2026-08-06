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
  # When the server is next due to restart, or nothing when there is no countdown to give. The sidebar already says
  # whether the server is up, so a server that is down or one ESM has never seen start simply drops the line rather
  # than restating offline.
  #
  # An estimate by nature: the interval is measured from when the server last finished starting, while owners tend to
  # schedule restarts on the hour, so this drifts by however long the last boot took. Handed to the page as an instant
  # rather than a sentence so it can keep counting down without a reload.
  #
  # @param server [ESM::Server]
  #
  # @return [ActiveSupport::TimeWithZone, nil]
  #
  def server_restart_at(server)
    return unless server.connected? && server.server_start_time?

    server.server_start_time + server.restart_interval
  end

  ##
  # Whether an empty live panel is worth explaining. A server ESM isn't talking to needs no explanation past the
  # status line above, and a player can't fix an address they don't own, so the only reader owed anything is someone
  # who manages a server that is up and still not answering.
  #
  # @param server [ESM::Server]
  #
  # @return [Boolean]
  #
  def server_query_unreachable?(server)
    server.connected? && server_manageable?(server)
  end

  ##
  # Points at the address the query went to, since that is the one part of this an owner controls from inside ESM. A
  # server that is up and silent has usually been given the wrong ip or port here rather than broken elsewhere, so the
  # address is set apart from the prose to be read character by character. Assembled here rather than interpolated
  # into the template because the ip is whatever an owner typed into the server form.
  #
  # @param server [ESM::Server]
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def server_query_unreachable_message(server)
    address = tag.code("#{server.server_ip}:#{server.query_port}", class: "text-warning-emphasis")

    safe_join(["No answer from ", address, " over UDP. Check this server's IP and port in its settings."])
  end

  ##
  # The server's mods grouped for display: required first, since those are what a player has to install before they
  # can connect at all. An empty group is dropped so a server with no optional mods shows no empty heading.
  #
  # The count rides in the label because the list itself collapses. A server with a hundred mods would otherwise
  # stretch the sidebar past everything else on the page, and how many there are is the part a returning player
  # actually reads.
  #
  # @param server [ESM::Server]
  #
  # @return [Array<Datum>] each responds to #label, #dom_id and #mods
  #
  def server_mod_groups(server)
    mods = server.server_mods.sort_by { |mod| mod.mod_name.to_s.downcase }
    required, optional = mods.partition(&:mod_required?)

    [
      Datum.new(label: "Required mods (#{required.size})", dom_id: "server-mods-required", mods: required),
      Datum.new(label: "Optional mods (#{optional.size})", dom_id: "server-mods-optional", mods: optional)
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
