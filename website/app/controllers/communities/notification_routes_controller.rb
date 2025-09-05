# frozen_string_literal: true

module Communities
  class NotificationRoutesController < AuthenticatedController
    before_action :check_for_community_access!

    def index
      pending_routes = current_community.user_notification_routes
        .pending_community_acceptance
        .by_user_community_channel_and_server

      routes = current_community.user_notification_routes
        .accepted
        .by_user_community_channel_and_server

      render locals: {
        pending_routes:,
        routes:,
        route_card_paths:
      }
    end

    def update
      route = current_community.user_notification_routes.find_by(public_id: params[:id])
      not_found! if route.nil?
      not_found! unless route.community_accepted?

      route.update!(enabled: params[:enabled])

      message = "Route <strong>#{route.enabled? ? "enabled" : "disabled"}</strong>"
      render turbo_stream: create_success_toast(message)
    end

    def accept
      ids = params[:ids].to_a
      not_found! if ids.blank?

      routes = current_community.user_notification_routes.where(public_id: ids)
      not_found! if routes.blank? || routes.size != ids.size

      routes.update_all(community_accepted: true, updated_at: Time.current)
      notify_channel(routes)

      flash[:success] = "Request accepted"

      redirect_to community_notification_routes_path
    end

    def decline
      ids = params[:ids].to_a
      not_found! if ids.blank?

      routes = current_community.user_notification_routes.where(public_id: ids)
      not_found! if routes.blank? || routes.size != ids.size

      routes.delete_all

      flash[:success] = "Request declined"

      redirect_to community_notification_routes_path
    end

    def destroy
      route = current_community.user_notification_routes.find_by(public_id: params[:id])
      not_found! if route.nil?

      route.destroy!

      toast = create_success_toast("Route removed")

      # The community does not have any more routes. Reload the page
      if current_community.user_notification_routes.size == 0
        render turbo_stream: [turbo_stream.refresh(request_id: nil), toast]
        return
      end

      # Get all remaining routes for this user
      existing_routes = current_community.user_notification_routes
        .where(user_id: route.user_id)
        .by_user_community_channel_and_server
        .values
        .first

      # This user has no more routes, remove their section
      if existing_routes.nil?
        render turbo_stream: [turbo_stream.remove(route.user.dom_id), toast]
        return
      end

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
      routes = current_community.user_notification_routes
        .includes(:destination_community, :source_server)
        .where(public_id: params[:ids])

      not_found! if routes.blank?

      routes.each(&:destroy!)

      flash[:success] = "Routes have been removed"

      redirect_to community_notification_routes_path
    end

    private

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
        destroy_many: method(:destroy_many_community_notification_routes_path)
          .curry(2)
          .call(current_community),
        routing: method(:community_notification_route_path).curry(2).call(current_community)
      }
    end
  end
end
