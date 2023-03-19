class PrivateServers < ActiveRecord::Migration[6.1]
  def change
    add_column(:servers, :server_visibility, :integer, if_not_exists: true)
    add_index(:servers, :server_visibility)
  end
end
