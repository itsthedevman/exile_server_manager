# frozen_string_literal: true

# Set to zero for indefinite
SPEC_TIMEOUT_SECONDS = 3
LOG_LEVEL = :error

RSpec.configure do |config|
  require_relative "spec_helper_pre_init"

  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Timeout for rspec/wait, default timeout for requests
  config.wait_timeout = SPEC_TIMEOUT_SECONDS.zero? ? 999_999_999 : SPEC_TIMEOUT_SECONDS

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before :suite do
    FactoryBot.definition_file_paths = [ESM.root.join("spec", "support", "factories")]
    FactoryBot.find_definitions
    DatabaseCleaner.strategy = :deletion
  end

  config.around do |example|
    trace!(
      example_group: example.example_group&.description,
      example: example.description
    )

    ESM::Test.reset!

    # Run the test!
    DatabaseCleaner.cleaning { example.run }

    ESM::Websocket.remove_all_connections!
  end

  config.before(:context, :territory_admin_bypass) do
    before_connection do
      community.update!(territory_admin_ids: [community.everyone_role_id])
    end
  end

  config.after(:context, :territory_admin_bypass) do
    ESM::Test.callbacks.remove_all_callbacks!
  end

  config.before(:context, :error_testing) do
    disable_log_printing
  end

  config.after(:context, :error_testing) do
    enable_log_printing
  end

  config.before(:each, :requires_connection) do
    if connection_server.nil? || !connection_server&.tcp_server_alive?
      raise "Unable to connect to the connection server. Is it running?"
    end

    ESM::ExileTerritory.delete_all

    ESM::Test.callbacks.run_callback(:before_connection, on_instance: self)
    ESM::Connection::Server.resume

    wait_for { connection_server&.tcp_server_alive? }.to be(true)
    wait_for { server.reload.connected? }.to be(true),
      "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    ESM::Test.outbound_server_messages.clear

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)
    next if users.blank?

    users.each do |user|
      # Creates a user on the server with the same steam_uid
      allow(user).to receive(:connect) { |**attrs| spawn_test_user(user, on: server, **attrs) }
    end
  rescue ActiveRecord::ConnectionNotEstablished
    raise "Unable to connect to the Exile MySQL server. Please ensure it is running before trying again"
  end

  config.after(:each, :requires_connection) do
    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)

    users = users.format(join_with: "\n") do |user|
      next if user.steam_uid.blank?

      "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if user.connected
    end

    if users.present?
      sqf =
        <<~SQF
          private _deleteFunction = {
            if (isNil "_this") exitWith {};

            deleteVehicle _this;
          };
          #{users}
        SQF

      execute_sqf!(sqf)
    end

    if (connection_server = ESM::Connection::Server.instance)
      # Ensure every message is either replied to or timed out
      wait_for { connection_server.message_overseer.size }.to eq(0), connection_server.message_overseer.mailbox.to_s

      # Pause the server in case it was started in the test
      connection_server.pause
      connection_server.disconnect_all!
      connection_server.message_overseer.remove_all!
    end
  end
end

# Wait until everything is ready
# HEY! LISTEN! The following lines must be the last code to execute in this file
ESM.console!
ESM.run!
ESM::Test.wait_until { ESM::Database.connected? }
ESM::Test.wait_until { ESM.bot.ready? }
