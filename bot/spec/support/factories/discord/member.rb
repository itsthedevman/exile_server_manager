# frozen_string_literal: true

FactoryBot.define do
  factory :discord_member, class: "Discordrb::Member" do
    skip_create

    transient do
      user { build(:discord_user) }
      server { nil }
      roles { [] }
      nick { nil }
    end

    initialize_with do
      raise ArgumentError, "discord_member factory requires a :server" if server.nil?

      Discordrb::Member.new(
        {
          "user" => {
            "id" => user.id,
            "username" => user.username,
            "global_name" => user.username,
            "discriminator" => "0"
          },
          "roles" => roles.map { |role| role.id.to_s },
          "nick" => nick,
          "joined_at" => Time.now.iso8601,
          "flags" => 0
        },
        server,
        ESM.discord_bot
      )
    end

    after(:build) do |member, evaluator|
      evaluator.server.add_member(member)
    end
  end
end
