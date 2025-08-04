class CommunityIconUrl < ActiveRecord::Migration[7.2]
  def change
    add_column(:communities, :icon_url, :text, if_not_exists: true)
  end
end
