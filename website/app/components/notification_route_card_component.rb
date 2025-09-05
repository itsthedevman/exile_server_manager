# frozen_string_literal: true

class NotificationRouteCardComponent < ApplicationComponent
  include NotificationGrouping

  attr_reader :community, :user, :server, :channel, :all_routes

  def on_load(server:, channel:, routes:, paths:, community: nil, user: nil)
    @user = user
    @community = community
    @server = server
    @channel = channel
    @all_routes = routes
    @paths = paths
  end

  def destroy_many_path(...)
    @paths[:destroy_many].call(...)
  end

  def routing_path(...)
    @paths[:routing].call(...)
  end

  def render_route_group(group_name, routes)
    content_tag(
      :div,
      class: "mb-3",
      id: group_dom_id(group_name)
    ) do
      safe_join([
        render_group_header(group_name),
        render_route_rows(routes)
      ])
    end
  end

  def route_card_dom_id
    @route_card_dom_id ||= helpers.notification_route_card_dom_id(all_routes.first)
  end

  private

  def route_pending?(route)
    route.user_accepted? && !route.community_accepted?
  end

  def route_active?(route)
    route.user_accepted? && route.community_accepted?
  end

  def group_dom_id(group_name)
    "#{route_card_dom_id}-#{group_name}"
  end

  def render_group_header(group_name)
    content_tag(:h6, class: "small mb-2 d-flex align-items-center") do
      content_tag(:span, group_name.humanize.upcase, class: "fw-semibold")
    end
  end

  def render_route_rows(routes)
    safe_join(routes.map { |route| render_route_row(route) })
  end

  def render_route_row(route)
    row_classes = ["d-flex", "align-items-center", "justify-content-between", "mb-1", "route-row"]
    row_classes << "opacity-50" if route_pending?(route)

    content_tag(
      :div,
      class: row_classes,
      id: route.dom_id
    ) do
      safe_join([
        render_route_controls(route),
        render_route_delete_button(route)
      ])
    end
  end

  def render_route_controls(route)
    content_tag(:div, class: "d-flex align-items-center gap-2 flex-grow-1") do
      if route_pending?(route)
        render_pending_route(route)
      else
        render_route_checkbox(route)
      end
    end
  end

  def render_pending_route(route)
    content_tag(
      :div,
      class: "d-flex align-items-center gap-2",
      title: "Waiting for community approval"
    ) do
      safe_join([
        content_tag(:i, "", class: "bi bi-clock text-warning"),
        content_tag(:span, route.notification_type.titleize, class: "small text-muted")
      ])
    end
  end

  def render_route_checkbox(route)
    form_with(
      model: route,
      url: routing_path(route),
      method: :patch,
      local: false,
      class: "form-check form-switch mb-0",
      data: {controller: "auto-submit"}
    ) do |f|
      safe_join([
        f.check_box(
          :enabled,
          class: "form-check-input",
          name: :enabled,
          data: {action: "change->auto-submit#submit"}
        ),
        f.label(:enabled, route.notification_type.titleize, class: "small")
      ])
    end
  end

  def render_route_delete_button(route)
    button_to(
      routing_path(route),
      method: :delete,
      class: "btn btn-link btn-sm p-0 text-danger route-delete d-none",
      title: "Delete #{route.notification_type.titleize} route"
    ) do
      content_tag(:i, "", class: "bi bi-trash small")
    end
  end
end
