# frozen_string_literal: true

class Cleanup < ActiveRecord::Migration[7.0]
  def change
    remove_column(:users, :discord_discriminator, if_exists: true)

    rename_column(:command_configurations, :whitelist_enabled, :allowlist_enabled)
    rename_column(:command_configurations, :whitelisted_role_ids, :allowlisted_role_ids)
  end
end
