# frozen_string_literal: true

RSpec.shared_context("connection") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let!(:server) { ESM::Test.server(for: community) }
  let!(:connection_server) { ESM.connection_server }

  # Define this in your context and include any steam uids you'd like to be
  # added to territory admins for the server
  let(:territory_admin_uids) { [] }

  # Internal, used when spawning in players
  let(:_spawned_players) { [] }

  let(:territory_moderators) { [] }
  let(:territory_build_rights) { [] }
  let(:territory_owner) { ESM::Test.steam_uid }
  let(:territory) do
    owner_uid = territory_owner
    create(
      :exile_territory,
      owner_uid:,
      moderators: [owner_uid] + territory_moderators,
      build_rights: [owner_uid] + territory_moderators + territory_build_rights,
      server_id: server.id
    )
  end

  def execute_sqf!(code, **)
    server.execute_sqf!(code, **)
  end

  def spawn_player_for(user)
    net_id = user.connect_to(server)
    _spawned_players << user
    net_id
  end

  before do |example|
    ESM.redis.del("server_key_set")

    next unless example.metadata[:requires_connection]

    # Store the server key so the build tool can pick it up and write it
    ESM.redis.set("server_key", server.token.to_json)

    # In order to properly bind territory_admin_uids, the UIDs must be available by
    # server initialization. However, I haven't figured out an elegant way to make this
    # data available outside storing it somewhere globally and referencing it during
    # server initialization
    ESM::Test.territory_admin_uids = territory_admin_uids

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

    users = _spawned_players.join_map("\n") do |user|
      next if user.steam_uid.blank?

      "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if user.connected
    end

    sqf = ""
    if users.present?
      sqf += <<~SQF
        private _deleteFunction = {
          if (isNil "_this") exitWith {};

          deleteVehicle _this;
        };

        #{users}
      SQF
    end

    execute_sqf!(sqf) if sqf.present?
  ensure
    connection_server.pause
  end
end
