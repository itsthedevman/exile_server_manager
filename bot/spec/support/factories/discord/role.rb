# frozen_string_literal: true

FactoryBot.define do
  factory :discord_role, class: "Discordrb::Role" do
    skip_create

    transient do
      id { Spec::Snowflake.next }
      name { Faker::Job.title }
      server { nil }
      permissions { 0 }
      position { 1 }
    end

    initialize_with do
      Discordrb::Role.new(
        {
          "id" => id,
          "name" => name,
          "permissions" => permissions.to_s,
          "position" => position,
          "hoist" => false,
          "mentionable" => false,
          "managed" => false,
          "colors" => {"primary_color" => 0},
          "flags" => 0
        },
        ESM.discord_bot,
        server
      )
    end

    after(:build) do |role, evaluator|
      evaluator.server&.add_role(role)
    end
  end
end
