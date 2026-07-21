# frozen_string_literal: true

class RenameServerCommandsToServiceCommands < ActiveRecord::Migration[8.1]
  def change
    rename_table :server_commands, :service_commands
  end
end
