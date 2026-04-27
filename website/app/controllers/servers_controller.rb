# frozen_string_literal: true

class ServersController < AuthenticatedController
  before_action :check_for_community_access!

  def show
    redirect_to edit_community_server_path(current_community, params[:server_id])
  end

  def new
    render locals: {existing_server_ids:}
  end

  def edit
    server = find_server
    not_found! if server.nil?

    existing_server_mods = server.server_mods
      .select(:mod_name, :mod_link, :mod_version, :mod_required)
      .map do |mod|
        mod.attributes
          .except("id")
          .transform_keys { |k| k.to_s.split("_").second } # Remove "mod_"
      end

    existing_reward_items = server.server_rewards
      .select(:reward_items)
      .default
      .reward_items
      .each_with_object({}) do |(classname, quantity), hash|
        hash[SecureRandom.uuid] = {classname:, quantity:}
      end

    render locals: {
      server:,
      existing_server_mods:,
      existing_reward_items:,
      existing_server_ids: existing_server_ids - [server.local_id]
    }
  end

  def create
    server_params = permit_create_params

    server = current_community.servers.create!(server_params)

    # Add the default @Exile mod
    server.server_mods.create!(
      mod_name: "@ExileMod",
      mod_version: "1.0.4",
      mod_link: "https://steamcommunity.com/workshop/filedetails/?id=1487484880",
      mod_required: true
    )

    flash[:success] = "Server #{server.server_id} has been created"
    redirect_to edit_community_server_path(current_community, server)
  end

  def update
    server = find_server
    not_found! if server.nil?

    server_params, mod_params, reward_params, setting_params = permit_update_params

    ESM::Server.transaction do
      # Update the actual server
      server.update!(server_params)

      # Update mods for this server
      server.server_mods.destroy_all
      mod_params.each { |mod| server.server_mods.create!(mod) }

      # Update the server reward for this server (Since we don't have reward packages yet)
      server.server_rewards.default.update!(reward_params)

      # Create the settings
      server.server_setting.update!(setting_params)
    end

    # Cause the server to reconnect
    ESM.bot.update_server(server.id) if server.server_setting.server_needs_restarted?

    render turbo_stream: [
      turbo_stream.replace(
        "nav_servers_list",
        partial: "communities/nav_servers_list",
        locals: {current_community: current_community.reload, server:}
      ),
      create_success_toast("Server #{server.server_id} has been updated")
    ]
  end

  def destroy
    server = find_server
    not_found! if server.nil?

    server.destroy!

    flash[:success] = "#{server.server_id} has been deleted"
    redirect_to community_path(current_community)
  end

  def enable_v2
    server = find_server
    not_found! if server.nil?

    server.update!(ui_version: "2.0.0")

    redirect_to edit_community_server_path(current_community, server, migrating: true)
  end

  def disable_v2
    server = find_server
    not_found! if server.nil?

    server.update!(ui_version: "1.0.0")

    redirect_to edit_community_server_path(current_community, server)
  end

  # V1
  def key
    server = find_server
    not_found! if server.nil?

    send_data(server.server_key, filename: "esm.key")
  end

  def server_token
    server = find_server
    not_found! if server.nil?

    send_data(server.token.to_json, filename: "esm.key")
  end

  def server_config
    server = find_server
    not_found! if server.nil?

    config = render_to_string(
      template: "servers/config",
      locals: {settings: server.server_setting.attributes},
      layout: false
    )

    send_data(config, filename: "config.yml")
  end

  def available
    # When we're validating the provided server ID, we need to make sure validation passes
    # if the ID hasn't been changed.
    if params[:server_id]
      server = current_community.servers.select(:server_id).find_by(public_id: params[:server_id])
      not_found! if server.nil?

      if server.local_id == params[:id]
        render json: {available: true}
        return
      end
    end

    exists = current_community.servers.with_local_id(params[:id]).exists?

    render json: {available: !exists}
  end

  private

  def find_server
    current_community.servers
      .includes(:server_mods, :server_rewards, :server_setting)
      .find_by(public_id: params[:server_id])
  end

  def existing_server_ids
    current_community.servers
      .select(:server_id)
      .map(&:local_id)
      .sort_by
      .insensitive
      .sort
  end

  def permit_create_params
    permitted_params = params.require(:server).permit(
      :server_id, :server_ip, :server_port,
      :server_visibility, :ui_version
    )

    sanitize_info_params(permitted_params)
  end

  def permit_update_params
    permitted_params = params.require(:server).permit(
      :server_id, :server_ip, :server_port,
      :server_visibility, :ui_version,
      server_rewards: [
        :player_poptabs,
        :locker_poptabs,
        :respect,
        reward_items: [:classname, :quantity]
      ],
      server_mods: [:name, :version, :link, :required],
      server_settings: [
        :gambling_locker_limit_enabled,
        :gambling_payout_base, :gambling_modifier,
        :gambling_payout_randomizer_min, :gambling_payout_randomizer_mid,
        :gambling_payout_randomizer_max, :gambling_win_percentage,
        :logging_add_player_to_territory, :logging_demote_player, :logging_exec, :logging_gamble,
        :logging_modify_player, :logging_pay_territory, :logging_promote_player,
        :logging_remove_player_from_territory, :logging_reward_player, :logging_transfer_poptabs,
        :logging_upgrade_territory,
        :max_payment_count,
        :territory_payment_tax, :territory_upgrade_tax, :territory_price_per_object,
        :territory_lifetime,
        :server_restart_hour, :server_restart_min,
        :database_uri, :exile_logs_search_days,
        :extdb_conf_header_name, :extdb_conf_path, :extdb_version,
        :log_output, :logging_path, :number_locale, :server_mod_name,
        :request_thread_type, :request_thread_tick, # V1
        additional_logs: []
      ]
    )

    info_params = permitted_params.except(:server_mods, :server_settings, :server_rewards)

    [
      sanitize_info_params(info_params),
      sanitize_mod_params(permitted_params[:server_mods]),
      sanitize_reward_params(permitted_params[:server_rewards]),
      sanitize_setting_params(permitted_params[:server_settings])
    ]
  end

  def sanitize_info_params(permitted_params)
    permitted_params[:server_id] =
      "#{current_community.community_id}_#{permitted_params[:server_id]}"

    version = permitted_params.delete(:ui_version)
    permitted_params[:ui_version] = "#{version}.0.0" if ["1", "2"].include?(version)

    permitted_params
  end

  def sanitize_mod_params(permitted_params)
    return [] if permitted_params.blank?

    permitted_params.map! { |mod| mod.transform_keys! { |k| "mod_#{k}" } } # Add back "mod_"
  end

  def sanitize_reward_params(permitted_params)
    return {} if permitted_params.blank?

    permitted_params[:reward_items] =
      if (reward_items = permitted_params[:reward_items]) && reward_items.present?
        reward_items
          .group_by_key(:classname)
          .transform_values { |items| items.map { |i| i[:quantity].to_i }.sum }
          .reject { |classname, quantity| classname.blank? || quantity.zero? }
      else
        {}
      end

    permitted_params[:reward_items].permit!
    permitted_params[:player_poptabs] ||= 0
    permitted_params[:locker_poptabs] ||= 0
    permitted_params[:respect] ||= 0

    permitted_params
  end

  def sanitize_setting_params(permitted_params)
    # Remove any empty strings
    permitted_params.transform_values!(&:presence)

    permitted_params[:additional_logs] =
      if (paths = permitted_params[:additional_logs]) && paths.present?
        paths.uniq.compact_blank
      else
        []
      end

    permitted_params
  end
end
