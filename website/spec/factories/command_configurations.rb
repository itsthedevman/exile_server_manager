# frozen_string_literal: true

FactoryBot.define do
  factory :command_configuration, class: "ESM::CommandConfiguration" do
    community

    # A spec always names the command and the setting it overrides.
    command_name { "test_command" }

    # A community seeds one row per command the moment it is created, so building a fresh row here would leave two for
    # the same command. The lookup indexes them by name, and which of the two wins is then down to the order Postgres
    # returns them in. Overriding the seeded row keeps a spec's setting the only one there is.
    initialize_with { ESM::CommandConfiguration.find_or_initialize_by(community:, command_name:) }
  end
end
