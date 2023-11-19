# frozen_string_literal: true

namespace :commands do
  task register_commands_for_development: :bot do
    return unless ESM.env.development?

    ESM::Community.all.pluck(:guild_id).each do |community_discord_id|
      ESM::Command.register_commands(community_discord_id)
    end
  end

  task register_commands_globally: :bot do
    ESM::Command.register_commands
  end
end
