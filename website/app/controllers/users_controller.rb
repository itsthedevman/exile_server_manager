# frozen_string_literal: true

class UsersController < AuthenticatedController
  def edit
    all_communities = ESM::Community.select(:id, :community_id, :community_name)
      .order("UPPER(community_id)")
      .load

    servers_by_community = ESM::Server.select(:id, :community_id, :server_id, :server_name)
      .includes(:community)
      .order("UPPER(server_id)")
      .load
      .group_by(&:community)
      .sort_by.method(:first).case_insensitive
      .to_a
      .to_h

    id_defaults = current_user.id_defaults
    id_aliases = current_user.id_aliases
      .includes(:community, :server)
      .load
      .sort_by(:value).case_insensitive
      .map(&:public_attributes)
      .index_by { |a| a["id"] }

    render locals: {
      # Defaults
      id_defaults:,
      default_community_select_data:
        helpers.generate_community_select_data(all_communities, id_defaults.community_id),
      default_server_select_data:
        helpers.generate_server_select_data(servers_by_community, id_defaults.server_id),

      # Aliases
      id_aliases:,
      alias_community_select_data: helpers.generate_community_select_data(
        all_communities,
        value_method: ->(community) { "#{community.community_id}:#{community.community_name}" }
      ),
      alias_server_select_data: helpers.generate_server_select_data(
        servers_by_community,
        value_method: ->(server) { "#{server.server_id}:#{server.server_name}" }
      )
    }
  end

  def update
    permitted_params = permit_update_params!

    if (id_defaults = permitted_params[:defaults])
      update_id_defaults!(id_defaults)
    end

    if (id_aliases = permitted_params[:aliases])
      update_id_aliases!(id_aliases)
    else
      current_user.id_aliases.delete_all
    end

    render turbo_stream: create_success_toast("Your settings have been updated")
  end

  def transfer
    not_found! if session[:transferring_steam_uid].blank?

    steam_uid = session.delete(:transferring_steam_uid)

    if params[:cancel]
      render turbo_stream: create_success_toast("Transfer cancelled")
      return
    end

    # Unset all users with this steam_uid
    ESM::User.where(steam_uid:).update_all(steam_uid: "")

    # Transfer this uid to the new user and refresh their data
    current_user.update!(steam_uid:)

    # Notify them on Discord
    ESM.bot.send_message(**current_user.welcome_message_hash)

    flash[:success] = {
      title: "Welcome #{current_user.steam_data.username}!",
      body: "You are now registered with ESM<br/>We've sent you a message via Discord to help you get started"
    }

    redirect_to edit_users_path
  end

  def destroy
    current_user.destroy!
    sign_out(current_user)

    flash[:success] = "Your account has been deleted"
    redirect_to root_path
  end

  def deregister
    current_user.deregister!

    flash[:success] = "You've been deregistered.<br/>You can reregister via the Sign into Steam button"
    redirect_to edit_users_path
  end

  private

  def permit_update_params!
    params.require(:user).permit(
      defaults: [:community_id, :server_id],
      aliases: [:value, :community_id, :server_id]
    )
  end

  def update_id_defaults!(id_defaults)
    if (community_id = id_defaults.delete(:community_id))
      id_defaults[:community_id] = ESM::Community.with_community_id(community_id).pick(:id)
    end

    if (server_id = id_defaults.delete(:server_id))
      id_defaults[:server_id] = ESM::Server.with_server_id(server_id).pick(:id)
    end

    ESM::UserDefault.where(user_id: current_user.id).update!(id_defaults)
  end

  def update_id_aliases!(id_aliases)
    community_lookup = ESM::Community.all.pluck(:community_id, :id)
      .to_h
      .transform_keys(&:downcase)

    server_lookup = ESM::Server.all.pluck(:server_id, :id)
      .to_h
      .transform_keys(&:downcase)

    ESM::UserAlias.transaction do
      current_user.id_aliases.delete_all

      id_aliases.each do |ali|
        if (community_id = ali.delete(:community_id))
          ali[:community_id] = community_lookup[community_id]
        end

        if (server_id = ali.delete(:server_id))
          ali[:server_id] = server_lookup[server_id]
        end

        ali[:user_id] = current_user.id

        ESM::UserAlias.create!(ali)
      end
    end
  end
end
