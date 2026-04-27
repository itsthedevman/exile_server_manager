# frozen_string_literal: true

class RouteRequestCardComponent < ApplicationComponent
  include NotificationGrouping

  attr_reader :user, :server, :channel, :all_routes

  def on_load(user:, server:, channel:, routes:, community: nil)
    @user = user
    @server = server
    @channel = channel
    @all_routes = routes
    @community = community
  end

  def render_route_group(group_name, routes)
    content_tag :div, class: "mb-3" do
      safe_join([
        # Group header
        content_tag(:div, class: "text-uppercase text-muted small fw-bold mb-2") do
          group_name.humanize
        end,
        # Route items as bulleted list
        content_tag(:div, class: "ms-2") do
          safe_join(routes.map do |route|
            content_tag :div, class: "text-light small mb-1" do
              safe_join([
                content_tag(:span, "• ", class: "me-1"),
                route.notification_type.titleize
              ])
            end
          end)
        end
      ])
    end
  end
end
