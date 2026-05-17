# frozen_string_literal: true

# Test-only attr_accessors used by the V1 (websocket) factory layer to attach
# channel/role lists pulled from the underlying Discordrb::Server. Real fields
# on the Community AR model are unaffected.
module ESM
  class Community < ApplicationRecord
    attr_accessor :role_ids, :channel_ids, :everyone_role_id
  end
end
