# frozen_string_literal: true

class SyncCommandConfigurationsForCommunityJob
  include ::SuckerPunch::Job
  workers 5

  def perform(community_id, configurations)
    ActiveRecord::Base.connection_pool.with_connection do
      # Get all existing configurations by command_name
      existing_configuration_names = ESM::CommandConfiguration.where(community_id: community_id).pluck(:command_name)

      # Remove any existing configurations
      configurations = configurations.reject { |config| existing_configuration_names.include?(config[:command_name]) }

      # Nothing to insert
      return if configurations.blank?

      # Merge in the ID for this community for mass inserts
      configurations = configurations.map { |config| config.merge(community_id: community_id) }

      # Mass insert
      ESM::CommandConfiguration.import(configurations)
    end
  end
end
