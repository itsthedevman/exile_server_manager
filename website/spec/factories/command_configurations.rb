# frozen_string_literal: true

FactoryBot.define do
  factory :command_configuration, class: "ESM::CommandConfiguration" do
    community

    # Every other column has a database default, and those defaults are deliberately not the command class's own: a
    # row exists precisely when a community has overridden something, so a spec building one always names both the
    # command and the setting it is overriding.
    command_name { "test_command" }
  end
end
