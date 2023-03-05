RSpec.shared_context("connection") do
  let(:community) { ESM::Test.community }
  let(:server) { ESM::Test.server }
  let(:user) { ESM::Test.user }
  let(:connection) { server.connection }

  #
  # Sends the provided SQF code to the linked connection.
  #
  # @param code [String] Valid and error free SQF code as a string
  #
  # @return [Any] The result of the SQF code.
  #
  # @note: The result is ran through a JSON parser during the communication process. The type may not be what you expect, but it will be consistent
  #
  def execute_sqf!(code)
    message = ESM::Message.arma.set_data(:sqf, {execute_on: "server", code: ESM::Arma::Sqf.minify(code)})

    message.add_attribute(
      :command, {
        current_user: {
          steam_uid: user.steam_uid || "",
          id: "",
          username: "",
          mention: ""
        }
      }.to_ostruct
    ).apply_command_metadata

    connection.send_message(message, forget: false)
  end

  before(:each) do |example|
    next unless example.metadata[:requires_connection]

    ESM::Connection::Server.resume

    wait_for { ESM::Connection::Server.instance&.tcp_server_alive? }.to be(true)
    wait_for { server.connected? }.to be(true), "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    ESM::Test.outbound_server_messages.clear

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)
    next if users.blank?

    users.each do |user|
      # Creates a user on the server with the same steam_uid
      allow(user).to receive(:connect) { |**attrs| spawn_test_user(user, on: connection, **attrs) }
    end
  end

  after(:each) do |example|
    next unless example.metadata[:requires_connection]

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)

    sqf = users.format(join_with: "\n") do |user|
      "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if user.connected
    end

    if sqf.present?
      execute_sqf!(
        <<~SQF
          private _deleteFunction = {
            if (isNil "_this") exitWith {};

            deleteVehicle _this;
          };
          #{sqf}
        SQF
      )
    end

    ESM::Connection::Server.pause
  end
end
