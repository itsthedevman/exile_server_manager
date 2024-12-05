class AddUuidToLogEntries < ActiveRecord::Migration[7.2]
  def change
    ########################################################
    # All of this just for uuid
    remove_index :log_entries, [:log_id, :log_date], if_exists: true
    remove_index :log_entries, [:log_id, :log_date, :file_name], if_exists: true

    remove_foreign_key :log_entries, :logs, if_exists: true

    create_table :log_entries_new, if_not_exists: true do |t|
      t.uuid :uuid, null: false
      t.references :log, null: false, foreign_key: true, index: true
      t.datetime :log_date
      t.string :file_name, null: false
      t.json :entries

      t.index :uuid
      t.index [:log_id, :log_date]
      t.index [:log_id, :log_date, :file_name]
    end

    ESM::LogEntry.all.each do |entry|
      connection.execute(
        ESM::ApplicationRecord.sanitize_sql_array([
          <<~SQL,
            INSERT INTO log_entries_new (uuid, log_id, log_date, file_name, entries)
            VALUES (?, ?, ?, ?, ?)
          SQL
          SecureRandom.uuid,
          entry[:log_id],
          entry[:log_date],
          entry[:file_name],
          entry[:entries].to_json
        ])
      )
    end

    drop_table(:log_entries)
    rename_table(:log_entries_new, :log_entries)
  end
end
