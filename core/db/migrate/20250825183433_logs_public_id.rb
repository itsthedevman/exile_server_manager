class LogsPublicID < ActiveRecord::Migration[7.2]
  def change
    rename_column(:logs, :uuid, :public_id)
    rename_column(:log_entries, :uuid, :public_id)
  end
end
