# frozen_string_literal: true

class CommunitiesController < AuthenticatedController
  before_action :check_for_community_access!, except: [:index]

  def index
    server_communities = current_user.server_communities.load
    player_communities = current_user.player_communities.load

    render locals: {
      server_communities:,
      player_communities:
    }
  end

  def show
    redirect_to edit_community_path(current_community)
  end

  def edit
    # Array<id="", name="", color="", disabled=false>
    community_roles = current_community.roles.sort_by(&:name)

    territory_admin_roles = community_roles.map do |role|
      selected = current_community.territory_admin_ids.include?(role.id)

      role_to_hash(role, selected:)
    end

    access_roles = community_roles.map do |role|
      selected = current_community.dashboard_access_role_ids.include?(role.id)

      role_to_hash(role, selected:)
    end

    render locals: {community_roles:, territory_admin_roles:, access_roles:}
  end

  def update
    community_id = params.dig(:community, :community_id)
    community_id = community_id.downcase if community_id.present?

    if community_id.size < 2
      render turbo_stream: create_error_toast("Community ID must be at least 2 characters")
      return
    end

    community_params = permit_community_params
    (community_params[:territory_admin_ids] ||= []).compact_blank!
    (community_params[:dashboard_access_role_ids] ||= []).compact_blank!

    # The ID has changed, update the community and servers
    if community_id.present? && community_id != current_community.community_id
      # Check to see if it exists
      if ESM::Community.by_community_id(community_id).exists?
        render turbo_stream: create_error_toast(
          "<code>#{community_id}</code> is already in use, please provide a different ID"
        )

        return
      end

      current_community.update_community_id!(community_id)
    end

    current_community.update!(community_params)

    render turbo_stream: create_success_toast("<code>#{community_id}</code> has been updated")
  end

  def destroy
    success = ESM.bot.delete_community(current_community.id, current_user.id)

    if !success
      ESM.log!(error: {
        message: "Failed to delete community",
        community: current_community,
        user: current_user,
        errors: current_community.errors
      })

      not_found!
    end

    flash[:success] = "#{current_community.community_name} has been removed from ESM"
    redirect_to communities_path
  end

  def available
    if current_community.community_id == params[:id]
      render json: {available: true}
      return
    end

    exists = ESM::Community.with_community_id(params[:id]).exists?
    render json: {available: !exists}
  end

  private

  def role_to_hash(role, selected: false)
    {
      label: role.name,
      value: role.id,
      disabled: role.disabled,
      selected:
    }
  end

  def permit_community_params
    # Purposely not including :community_id
    params.require(:community).permit(
      :logging_channel_id,
      :log_reconnect_event, :log_xm8_event, :log_discord_log_event,
      :welcome_message_enabled, :welcome_message,
      territory_admin_ids: [], dashboard_access_role_ids: []
    )
  end
end
