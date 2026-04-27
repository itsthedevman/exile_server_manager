class RemoveAllowV2Servers < ActiveRecord::Migration[7.2]
  def change
    remove_column(:communities, :allow_v2_servers, if_exists: true)
  end
end
