# frozen_string_literal: true

#
# `standalone_migrations` expects to live inside a Rails app and reads
# `Rails.root` to locate its config and migration files. We're not Rails,
# so stub the bare minimum it needs to work.
#

module Rails
  def self.root
    ESM_SERVICE_PATH
  end
end
