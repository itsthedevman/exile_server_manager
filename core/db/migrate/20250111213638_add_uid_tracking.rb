class AddUIDTracking < ActiveRecord::Migration[6.1]
  def change
    create_table :user_steam_uid_histories, if_not_exists: true do |t|
      t.belongs_to :user, foreign_key: {on_delete: :nullify}, index: true
      t.string :previous_steam_uid
      t.string :new_steam_uid
      t.timestamps

      t.index [:previous_steam_uid, :new_steam_uid], name: :idx_steam_uids
      t.index :created_at
    end
  end
end
