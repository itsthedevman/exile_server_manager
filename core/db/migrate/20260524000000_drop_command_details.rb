# frozen_string_literal: true

class DropCommandDetails < ActiveRecord::Migration[8.1]
  def change
    drop_table :command_details
  end
end
