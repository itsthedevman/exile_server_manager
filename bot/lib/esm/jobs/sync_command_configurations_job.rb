# frozen_string_literal: true

class SyncCommandConfigurationsJob
  include ::SuckerPunch::Job

  def perform(_)
    ESM::ApplicationRecord.connection_pool.with_connection do
      community_ids = ESM::Community.all.pluck(:id)

      community_ids.each do |community_id|
        SyncCommandConfigurationsForCommunityJob.perform_async(community_id, ESM::Command.configurations)
      end
    end
  end
end
