# frozen_string_literal: true

FactoryBot.define do
  factory :request, class: "ESM::Request" do
    # attribute :uuid, :uuid
    # attribute :uuid_short, :string
    # attribute :requestor_user_id, :integer
    # attribute :requestee_user_id, :integer
    # attribute :requested_from_channel_id, :string
    # attribute :command_name, :string
    # attribute :command_arguments, :json, default: nil
    # attribute :expires_at, :datetime
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime

    command_name { "reward" }
    command_arguments { nil }
    requested_from_channel_id { "" }
  end
end
