class UserNotificationRoutes < ActiveRecord::Migration[6.1]
  def change
    create_table :user_notification_routes do |t|
      t.uuid :uuid, index: true, null: false
      t.integer :user_id, null: false
      t.integer :source_server_id, null: true
      t.integer :destination_community_id, null: false
      t.string :channel_id, null: false
      t.string :notification_type, null: false
      t.boolean :enabled, default: true, null: false
      t.boolean :user_accepted, default: false, null: false
      t.boolean :community_accepted, default: false, null: false
      t.timestamps
    end

    add_foreign_key :user_notification_routes, :users
    add_foreign_key :user_notification_routes, :servers, column: :source_server_id
    add_foreign_key :user_notification_routes, :communities, column: :destination_community_id
  end
end
