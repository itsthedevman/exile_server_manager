class ServerCommandResult < ActiveRecord::Migration[8.1]
  def change
    change_table(:server_commands) do |t|
      t.jsonb :result
    end
  end
end
