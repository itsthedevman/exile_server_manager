# frozen_string_literal: true

class CreateDefaultsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :community_defaults, if_not_exists: true do |t|
      t.belongs_to :community, foreign_key: {on_delete: :cascade}
      t.references :server, index: true, foreign_key: {on_delete: :cascade}
      t.string :channel_id
      t.timestamps

      t.index [:community_id, :channel_id]
    end

    create_table :user_defaults, if_not_exists: true do |t|
      t.belongs_to :user, index: true, foreign_key: {on_delete: :cascade}
      t.references :community, index: true, foreign_key: {on_delete: :cascade}
      t.references :server, index: true, foreign_key: {on_delete: :cascade}
      t.timestamps
    end

    create_table :user_aliases, if_not_exists: true do |t|
      t.uuid :uuid, index: true, unique: true
      t.belongs_to :user, foreign_key: {on_delete: :cascade}
      t.references :community, index: true, foreign_key: {on_delete: :cascade}
      t.references :server, index: true, foreign_key: {on_delete: :cascade}
      t.string :value, null: false
      t.timestamps

      t.index [:user_id, :community_id, :value], unique: true
      t.index [:user_id, :server_id, :value], unique: true
    end
  end
end
