RSpec.shared_context("connection") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server }
  let(:connection_server) { ESM::Connection::Server.instance }

  def execute_sqf!(code)
    ESM::Test.execute_sqf!(server, code, steam_uid: user.steam_uid)
  end

  before(:each) do |example|
    next unless example.metadata[:requires_connection]

    ESM::Test.callbacks.run_callback(:before_connection, on_instance: self)
    ESM::Connection::Server.resume

    wait_for { connection_server&.tcp_server_alive? }.to be(true)
    wait_for { server.reload.connected? }.to be(true), "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    ESM::Test.outbound_server_messages.clear

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)
    next if users.blank?

    users.each do |user|
      # Creates a user on the server with the same steam_uid
      allow(user).to receive(:connect) { |**attrs| spawn_test_user(user, on: server, **attrs) }
    end
  end

  after(:each) do |example|
    next unless example.metadata[:requires_connection]

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)

    users = users.format(join_with: "\n") do |user|
      next if user.steam_uid.blank?

      "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if user.connected
    end

    sqf = ""
    if users.present?
      sqf +=
        <<~SQF
          private _deleteFunction = {
            if (isNil "_this") exitWith {};

            deleteVehicle _this;
          };
          #{users}
        SQF
    end

    execute_sqf!(sqf) if sqf.present?
  end
end
