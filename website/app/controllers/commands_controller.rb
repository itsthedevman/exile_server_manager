# frozen_string_literal: true

class CommandsController < AuthenticatedController
  before_action :check_for_community_access!
  before_action :redirect_if_player_mode!

  def index
    configurations = current_community
      .command_configurations
      .order(:community_id)
      .index_by(&:command_name)

    commands_by_category = Command.all.values
      .sort_by(&:usage)
      .select(&:modifiable?)
      .each { |command| command.configuration = configurations[command.name] }
      .group_by(&:category)

    cooldown_types = ESM::Cooldown::TYPES.map { |t| [t.humanize, t] }

    render locals: {commands_by_category:, cooldown_types:}
  end

  def update
    command = current_community.command_configurations.find_by(command_name: params[:name])
    not_found! if command.nil?

    command.update!(command_params)

    render turbo_stream: create_success_toast(
      "<code>#{command.details.command_usage}</code> has been updated"
    )
  end

  private

  def command_params
    permitted_params = params.require(:command_configuration).permit(
      :enabled, :notify_when_disabled,
      :allowed_in_text_channels,
      :cooldown_quantity, :cooldown_type,
      :allowlist_enabled, allowlisted_role_ids: []
    )

    if (value = permitted_params[:enabled])
      permitted_params[:enabled] = value == "1"
    end

    if (value = permitted_params[:notify_when_disabled])
      permitted_params[:notify_when_disabled] = value == "1"
    end

    if (value = permitted_params[:allowed_in_text_channels])
      permitted_params[:allowed_in_text_channels] = value == "1"
    end

    if (value = permitted_params[:allowlist_enabled])
      permitted_params[:allowlist_enabled] = value == "1"
    end

    permitted_params[:allowlisted_role_ids]&.compact_blank!

    # Default invalid types to "times"
    if (type = permitted_params[:cooldown_type]) && !ESM::Cooldown::TYPES.include?(type)
      permitted_params[:cooldown_type] = "times"
    end

    permitted_params
  end
end
