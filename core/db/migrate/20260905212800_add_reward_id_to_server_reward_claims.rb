class AddRewardIdToServerRewardClaims < ActiveRecord::Migration[8.1]
  def change
    # Which package the claim was issued from, so settling it can put the cooldown on that package rather than
    # assuming the default. Not a foreign key and not an association: a claim's contents are a snapshot that has to
    # outlive the package being edited, and this is only the cooldown's scope key riding along with it.
    #
    # Null on purpose for a claim an admin created by hand. That player did not redeem a package, so finishing the
    # claim puts nothing on cooldown.
    add_column :server_reward_claims, :reward_id, :string
  end
end
