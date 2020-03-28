# frozen_string_literal: true

FactoryBot.define do
  factory :request, class: "ESM::Request" do
    # attribute :uuid, :uuid
    # attribute :uuid_short, :string
    # attribute :requestor_user_id, :integer
    # attribute :requestee_user_id, :integer
    # attribute :command_name, :string
    # attribute :command_arguments, :json, default: nil
    # attribute :expires_at, :datetime
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime

    uuid {}
    uuid_short {}
    requestor_user_id {}
    requestee_user_id {}
    command_name {}
    command_arguments {}
    expires_at {}
  end
end
