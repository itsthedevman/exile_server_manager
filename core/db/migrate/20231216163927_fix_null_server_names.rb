# frozen_string_literal: true

class FixNullServerNames < ActiveRecord::Migration[7.0]
  def up
    change_column(:servers, :server_name, :text, null: false, default: "")
  end

  def down
    change_column(:servers, :server_name, :text)
  end
end
