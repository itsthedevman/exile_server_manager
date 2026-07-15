# frozen_string_literal: true

class RequestStatus < ActiveRecord::Migration[8.1]
  def change
    change_table(:requests) do |t|
      t.string :status, null: false, default: "pending"

      t.index :status
    end
  end
end
