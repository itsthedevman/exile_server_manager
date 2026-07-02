class UserServerFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :user_server_favorites, if_not_exists: true do |t|
      t.uuid :public_id, null: false
      t.belongs_to :user, null: false, index: false, foreign_key: {on_delete: :cascade}
      t.belongs_to :server, null: false, foreign_key: {on_delete: :cascade}
      t.timestamps

      t.index :public_id, unique: true
      t.index [:user_id, :server_id], unique: true
    end
  end
end
