# frozen_string_literal: true

class ServerCommands < ActiveRecord::Migration[8.1]
  def change
    create_table :server_commands, if_not_exists: true do |t|
      t.belongs_to :server, index: true, foreign_key: {on_delete: :cascade}
      t.references :user, index: true, foreign_key: {on_delete: :cascade}
      t.uuid :idempotency_key, null: false
      t.string :command_name, null: false
      t.jsonb :arguments, default: {}
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.timestamps

      t.index [:user_id, :idempotency_key], unique: true
    end
  end
end
