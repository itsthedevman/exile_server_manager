class CreateServerRewardClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :server_reward_claims do |t|
      t.integer :server_id, null: false
      t.integer :user_id, null: false

      t.bigint :player_poptabs, default: 0, null: false
      t.bigint :locker_poptabs, default: 0, null: false
      t.bigint :respect, default: 0, null: false
      t.json :items, default: {}
      t.json :vehicles, default: []

      t.string :state, default: "waiting", null: false
      t.json :state_details, default: {}
      t.integer :attempt_count, default: 0, null: false
      t.datetime :last_attempt_at

      t.timestamps
    end

    add_index :server_reward_claims, [:server_id, :user_id], unique: true
  end
end
