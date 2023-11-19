# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    attr_accessor :guild_type, :role_ids, :channel_ids, :everyone_role_id

    module ESM
      SPAM_CHANNEL = ENV["SPAM_CHANNEL"]
    end

    module Secondary
      ID = ENV["SECONDARY_COMMUNITY_ID"]
      SPAM_CHANNEL = ENV["SECONDARY_SPAM_CHANNEL"]
    end
  end
end
