# frozen_string_literal: true

FactoryBot.define do
  factory :command_configuration, class: "ESM::CommandConfiguration" do
    association :community
    command_name { "test_command" }
    enabled { true }
    cooldown_quantity { 2 }
    cooldown_type { "seconds" }
    allowed_in_text_channels { true }
    allowlist_enabled { false }
    allowlisted_role_ids { [] }
  end
end
