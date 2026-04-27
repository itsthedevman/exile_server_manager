# frozen_string_literal: true

module NotificationRouteHelper
  def notification_route_card_dom_id(route)
    digest([
      route.channel_id,
      route.user_id,
      route.destination_community_id,
      route.source_server_id
    ].join("-"))
  end
end
