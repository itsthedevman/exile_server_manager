# frozen_string_literal: true

class RebuildCommandCacheJob
  include ::SuckerPunch::Job

  def perform(cache)
    # Remove all the caches since this will recache
    ESM::CommandDetail.in_batches(of: 10_000).delete_all

    # Store the caches in the DB so the website can read this data
    ESM::CommandDetail.import(cache)
  end
end
