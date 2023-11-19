# frozen_string_literal: true

class CreateApiTokensTable < ActiveRecord::Migration[6.1]
  def change
    create_table :api_tokens do |t|
      t.string :token, null: false, index: true
      t.boolean :active, default: true
      t.string :comment
      t.timestamps
    end
  end
end
