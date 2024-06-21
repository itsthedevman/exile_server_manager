# frozen_string_literal: true

RSpec.shared_context("connection") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let!(:server) { ESM::Test.server(for: community) }
  let!(:connection_server) { ESM.connection_server }
  let(:_spawned_players) { [] }

  def execute_sqf!(code, **)
    server.execute_sqf!(code, **)
  end

  def spawn_player_for(user)
    user.connect_to(server)
    _spawned_players << user
  end

  before do |example|
    ESM.redis.del("server_key_set")

    next unless example.metadata[:requires_connection]

    # Store the server key so the build tool can pick it up and write it
    ESM.redis.set("server_key", server.token.to_json)

    connection_server.resume

    wait_for { ESM.redis.exists?("server_key_set") }.to be(true)

    wait_for { server.reload.connected? }.to be(true),
      "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    server.reset!
  rescue ActiveRecord::ConnectionNotEstablished
    raise "Unable to connect to the Exile MySQL server. Please ensure it is running before trying again"
  end

  after do |example|
    next unless example.metadata[:requires_connection]
    next if _spawned_players.size == 0

    users = _spawned_players.map_join("\n") do |user|
      next if user.steam_uid.blank?

      "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if user.connected
    end

    sqf = "ESM_TerritoryAdminUIDs = [];"
    sqf += if users.present?
      <<~SQF
        private _deleteFunction = {
          if (isNil "_this") exitWith {};

          deleteVehicle _this;
        };

        #{users}
      SQF
    else
      "nil" # Arma vomits for whatever reason unless we return something
    end

    execute_sqf!(sqf)
  ensure
    connection_server.pause
  end

  def make_territory_admin!(user)
    # Arma vomits unless we return something like `nil`
    execute_sqf!("ESM_TerritoryAdminUIDs = [#{user.steam_uid.quoted}]; nil")
  end
end
