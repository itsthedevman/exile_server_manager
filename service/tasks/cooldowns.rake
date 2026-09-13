# frozen_string_literal: true

namespace :cooldowns do
  desc "Move reward cooldowns from before per-package cooldowns onto the default package (v2 servers only)"
  task backfill_reward_scope_keys: :environment do
    server_ids = ESM::Server.find_each.select(&:v2?).map(&:id)
    counts = {moved: 0, deleted: 0}

    ESM::Cooldown.transaction do
      ESM::Cooldown.where(command_name: "reward", scope_key: nil, server_id: server_ids).find_each do |cooldown|
        superseded = ESM::Cooldown.where(
          command_name: "reward",
          scope_key: "default",
          community_id: cooldown.community_id,
          server_id: cooldown.server_id,
          user_id: cooldown.user_id,
          steam_uid: cooldown.steam_uid
        ).exists?

        if superseded
          cooldown.destroy!
          counts[:deleted] += 1
        else
          cooldown.update!(scope_key: "default")
          counts[:moved] += 1
        end
      end
    end

    puts "Moved #{counts[:moved]} reward cooldowns onto the default package"
    puts "Deleted #{counts[:deleted]} that a newer default-package cooldown had already replaced"
  end
end
