class NotificationsPublicID < ActiveRecord::Migration[7.2]
  def up
    create_table :notifications_new do |t|
      t.uuid :public_id, null: false
      t.belongs_to :community, null: false, index: true
      t.string :notification_type, null: false
      t.string :notification_category
      t.text :notification_title
      t.text :notification_description
      t.string :notification_color
      t.timestamps

      t.index :public_id, unique: true
    end

    # Copy data with new UUIDs
    execute <<-SQL
      INSERT INTO notifications_new (
        public_id, community_id, notification_type, notification_category,
        notification_title, notification_description, notification_color,
        created_at, updated_at
      )
      SELECT
        gen_random_uuid(), community_id, notification_type, notification_category,
        notification_title, notification_description, notification_color,
        created_at, updated_at
      FROM notifications
    SQL

    drop_table :notifications
    rename_table :notifications_new, :notifications
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
