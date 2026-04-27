# frozen_string_literal: true

module NotificationGrouping
  def territory_management_routes(routes)
    types = ESM::UserNotificationRoute::GROUPS[:territory_management]

    [
      "territory_management",
      routes.select { |route| types.include?(route.notification_type) }
    ]
  end

  def base_combat_routes(routes)
    types = ESM::UserNotificationRoute::GROUPS[:base_combat]

    [
      "base_combat",
      routes.select { |route| types.include?(route.notification_type) }
    ]
  end

  def economy_routes(routes)
    types = ESM::UserNotificationRoute::GROUPS[:economy]

    [
      "economy",
      routes.select { |route| types.include?(route.notification_type) }
    ]
  end

  def custom_routes(routes)
    types = ESM::UserNotificationRoute::GROUPS[:custom]

    [
      "custom",
      routes.select { |route| types.include?(route.notification_type) }
    ]
  end
end
