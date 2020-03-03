# frozen_string_literal: true

FactoryBot.define do
  factory :command_configuration, class: "ESM::CommandConfiguration" do
    community_id {}
    command_name {}
    enabled { true }
    cooldown_quantity { 2 }
    cooldown_type { "seconds" }
    allowed_in_text_channels { true }
    whitelist_enabled { false }
    whitelisted_role_ids { [] }
  end
end
