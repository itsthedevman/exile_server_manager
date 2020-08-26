# frozen_string_literal: true

class SyncCommandConfigurationsJob
  include ::SuckerPunch::Job

  def perform(_)
    # Pre-cache the command configurations
    configurations =
      ESM::Command.all.map do |command|
        cooldown_default = command.defines.cooldown_time.default

        case cooldown_default
        when Enumerator
          cooldown_type = "times"
          cooldown_quantity = cooldown_default.size
        when ActiveSupport::Duration
          # Converts 2.seconds to [:seconds, 2]
          cooldown_type, cooldown_quantity = cooldown_default.parts.to_a.first
        end

        {
          command_name: command.name,
          enabled: command.defines.enabled.default,
          cooldown_quantity: cooldown_quantity,
          cooldown_type: cooldown_type,
          allowed_in_text_channels: command.defines.allowed_in_text_channels.default,
          whitelist_enabled: command.defines.whitelist_enabled.default,
          whitelisted_role_ids: command.defines.whitelisted_role_ids.default
        }
      end

    ActiveRecord::Base.connection_pool.with_connection do
      community_ids = ESM::Community.all.pluck(:id)

      community_ids.each do |community_id|
        SyncCommandConfigurationsForCommunityJob.perform_async(community_id, configurations)
      end
    end
  end
end
