# frozen_string_literal: true

module Users
  class NotificationRoutesController < AuthenticatedController
    def index
      routes = current_user.user_notification_routes
        .by_user_community_channel_and_server
        .values
        .first || []

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

      render locals: {
        routes:,
        community_select_data: helpers.generate_community_select_data(
          all_communities,
          value_method: ->(community) { "#{community.community_id}:#{community.community_name}" }
        ),
        server_select_data: helpers.generate_server_select_data(
          servers_by_community,
          value_method: ->(server) { "#{server.server_id}:#{server.server_name}" },
          select_all: true
        ),
        notification_type_select_data: generate_type_select_data,
        route_card_paths:
      }
    end

    def create
      permitted_params = permit_create_params!

      community = ESM::Community.find_by_community_id(permitted_params[:community_id])
      not_found! if community.nil?

      channel = ESM.bot.channel(permitted_params[:channel_id], user_id: current_user.id)
      not_found! if channel.nil?

      # Validate the servers
      server_ids = permitted_params[:server_ids]

      servers =
        if server_ids == "any"
          # We want to create one entry per type with a nil server ID
          [nil]
        else
          servers = ESM::Server.where(server_id: server_ids).select(:id)
          not_found! if servers.blank? || servers.size != server_ids.size

          servers
        end

      types = ESM::UserNotificationRoute::TYPES.select do |type|
        permitted_params[:types].include?(type)
      end

      # This auto accepts any requests
      auto_accept = community.modifiable_by?(current_user)

      queries = types.flat_map do |type|
        servers.map do |server|
          {
            public_id: SecureRandom.uuid,
            user_id: current_user.id,
            source_server_id: server&.id,
            destination_community_id: community.id,
            channel_id: channel[:id],
            notification_type: type,
            community_accepted: auto_accept || false,
            user_accepted: true
          }
        end
      end

      # Now we need to detect any routes that might exist and drop them from our insert
      existing_routes_query = current_user.user_notification_routes.where(
        destination_community_id: community.id,
        channel_id: channel[:id],
        notification_type: types
      )

      existing_routes_query =
        if server_ids == "any"
          existing_routes_query.where(source_server_id: nil)
        else
          existing_routes_query.where(source_server_id: servers.map(&:id))
        end

      existing_routes = existing_routes_query.pluck(:user_id, :source_server_id, :notification_type)
        .map { |id| id.join("-") }
        .to_set

      # Remove any duplicates
      queries.reject! do |query|
        key = "#{query[:user_id]}-#{query[:source_server_id]}-#{query[:notification_type]}"
        existing_routes.include?(key)
      end

      ESM::UserNotificationRoute.insert_all(queries)

      # Check if any were auto-accepted and notify the channel
      accepted_uuids = queries.select { |query| query[:community_accepted] && query[:user_accepted] }
        .key_map(:public_id)

      routes = ESM::UserNotificationRoute.all
        .where(public_id: accepted_uuids)
        .select(:user_id, :notification_type, :source_server_id, :channel_id)

      notify_channel(routes) if routes.present?

      flash[:success] = "Routes created"
      redirect_to users_notification_routes_path
    end

    def update
      route = current_user.user_notification_routes.find_by(public_id: params[:id])
      not_found! if route.nil?
      not_found! unless route.community_accepted?

      route.update!(enabled: params[:enabled])

      message = "Route <strong>#{route.enabled? ? "enabled" : "disabled"}</strong>"
      render turbo_stream: create_success_toast(message)
    end

    def destroy
      route = current_user.user_notification_routes.find_by(public_id: params[:id])
      not_found! if route.nil?

      route.destroy!

      toast = create_success_toast("Route removed")

      # The community does not have any more routes. Reload the page
      if current_user.user_notification_routes.size == 0
        render turbo_stream: [turbo_stream.replace("routes-container", partial: "no_routes"), toast]
        return
      end

      # Get all remaining routes for this user
      existing_routes = current_user.user_notification_routes
        .by_user_community_channel_and_server
        .values
        .first

      # If there are no routes left for this card, remove the card
      route_card = existing_routes.find do |group|
        group[:channel].id == route.channel_id &&
          group[:server]&.id == route.source_server_id &&
          group[:routes].size > 0
      end

      if route_card.nil?
        id = helpers.notification_route_card_dom_id(route)
        render turbo_stream: [turbo_stream.remove(id), toast]
        return
      end

      # If there are no more routes in the group, remove the group
      group_name = ESM::UserNotificationRoute::GROUPS
        .find { |_, types| types.include?(route.notification_type) }
        .first

      remove_group = route_card[:routes].none? do |route|
        ESM::UserNotificationRoute::TYPE_TO_GROUP[route.notification_type] == group_name
      end

      if remove_group
        id = helpers.notification_route_card_dom_id(route)
        render turbo_stream: [turbo_stream.remove("#{id}-#{group_name}"), toast]
        return
      end

      # Remove the route itself
      render turbo_stream: [turbo_stream.remove(route.dom_id), toast]
    end

    def destroy_many
      routes = current_user.user_notification_routes
        .includes(:destination_community, :source_server)
        .where(public_id: params[:ids])

      not_found! if routes.blank?

      routes.each(&:destroy!)

      flash[:success] = "Routes have been removed"

      redirect_to users_notification_routes_path
    end

    private

    def permit_create_params!
      # server_ids is defined twice because it can be either an array or string
      params.require(:routes).permit(
        :server_ids, :community_id, :channel_id, types: [], server_ids: []
      )
    end

    def notify_channel(routes)
      # Everything is grouped so all the requests are for one user
      # from one server routing to one channel
      template_route = routes.first
      user = template_route.user

      types_sentence =
        if ESM::UserNotificationRoute::TYPES.size == routes.size
          "all"
        else
          routes.map { |route| "`#{route.notification_type.titleize}`" }.to_sentence
        end

      server =
        if template_route.source_server
          "`#{template_route.source_server.server_id}`"
        else
          "any server"
        end

      ESM.bot.send_message(
        channel_id: template_route.channel_id,
        message: <<~STRING
          :incoming_envelope: #{user.mention}, this channel will now receive #{types_sentence} XM8 notifications sent to you from #{server}
        STRING
      )
    end

    def route_card_paths
      {
        destroy_many: method(:destroy_many_users_notification_routes_path),
        routing: method(:users_notification_route_path)
      }
    end

    def generate_type_select_data
      helpers.group_data_from_collection_for_slim_select(
        ESM::UserNotificationRoute::GROUPS,
        ->(key) { key.to_s.titleize.upcase },
        :itself,
        ->(i) { i.titleize },
        select_all: true,
        placeholder: true
      )
    end
  end
end
