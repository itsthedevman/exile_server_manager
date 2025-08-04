class V2Enable < ActiveRecord::Migration[7.2]
  def change
    add_column(:communities, :allow_v2_servers, :boolean, default: false, if_not_exists: true)
  end
end
