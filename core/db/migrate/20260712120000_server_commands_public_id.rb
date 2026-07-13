# frozen_string_literal: true

class ServerCommandsPublicId < ActiveRecord::Migration[8.1]
  def change
    add_column :server_commands, :public_id, :uuid

    # Backfill any rows created before this column existed (raw SQL so the
    # migration doesn't depend on the core models being loaded).
    up_only do
      execute("UPDATE server_commands SET public_id = gen_random_uuid() WHERE public_id IS NULL")
    end

    change_column_null :server_commands, :public_id, false
    add_index :server_commands, :public_id, unique: true
  end
end
