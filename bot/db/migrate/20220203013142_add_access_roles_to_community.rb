class AddAccessRolesToCommunity < ActiveRecord::Migration[6.1]
  def change
    add_column(:communities, :dashboard_access_role_ids, :json, default: [])
  end
end
