# frozen_string_literal: true

class SyncCommandCountsJob
  include ::SuckerPunch::Job

  def perform(_)
    ESM::ApplicationRecord.connection_pool.with_connection do
      ESM::Command.all.each do |command|
        ESM::CommandCount.where(command_name: command.name).first_or_create
      end
    end
  end
end
