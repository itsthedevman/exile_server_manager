class NotificationRoutesPublicID < ActiveRecord::Migration[7.2]
  def change
    rename_column(:user_notification_routes, :uuid, :public_id)
  end
end
