class V2Enabled < ActiveRecord::Migration[7.2]
  def change
    add_column(:communities, :allow_v2_servers, :boolean, default: false, if_not_exists: true)
    add_column(:servers, :ui_version, :string, default: "1.0.0", if_not_exists: true)
  end
end
