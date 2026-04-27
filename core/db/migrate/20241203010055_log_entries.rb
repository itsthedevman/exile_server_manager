class LogEntries < ActiveRecord::Migration[7.2]
  def change
    change_column(:log_entries, :log_date, :datetime, null: true)
  end
end
