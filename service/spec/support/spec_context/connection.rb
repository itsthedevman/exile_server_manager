# frozen_string_literal: true

RSpec.shared_context("connection") do
  # When nested inside "command", inherit its community/user so the
  # channel/discord_server/community/member lineage stays consistent. Without
  # this, `Community.from_discord` first_or_initializes a fresh community with
  # the schema default `player_mode_enabled: true` and admin command checks
  # all fail with "not available in player mode".
  let!(:community) do
    super()
  rescue NoMethodError
    if respond_to?(:discord_server, true)
      create(:community, discord_server: discord_server)
    else
      create(:community)
    end
  end

  let!(:user) do
    super()
  rescue NoMethodError
    create(:user)
  end

  let!(:server) { create(:server, community_id: community.id) }
  let!(:connection_server) { ESM::Arma::Server }

  # Define this in your context and include any steam uids you'd like to be
  # added to territory admins for the server
  let(:territory_admin_uids) { [] }

  # Internal, used when spawning in players
  let(:_spawned_players) { [] }

  let(:territory_moderators) { [] }
  let(:territory_build_rights) { [] }
  let(:territory_owner) { Faker::Steam.uid }
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

  def get_player_variable!(net_id, variable, default = nil)
    server.execute_sqf! <<~SQF
      private _playerObject = objectFromNetId "#{net_id}";
      if (isNull(_playerObject)) exitWith { nil };

      _playerObject getVariable ["#{variable}", #{default.to_json}]
    SQF
  end

  def reinitialize_server!
    server.connection.close

    wait(timeout: 5).for { server.reload.connected? }.to be(true)
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

    # The server.connected? check is flakey: Arma is genuinely connected but
    # the @connections map occasionally hasn't seen the public_id yet. Pause +
    # resume forces a fresh reconnect. Up to 3 attempts before we give up.
    max_attempts = 3
    attempts = 0
    begin
      attempts += 1
      connection_server.resume

      wait_for { ESM.redis.exists?("server_key_set") }.to be(true)
      wait(timeout: 5).for { server.reload.connected? }.to be(true)
    rescue RSpec::Expectations::ExpectationNotMetError
      if attempts >= max_attempts
        raise "esm_arma never connected after #{max_attempts} attempts. Run `bin/dev` from arma/ to start it. " \
              "Specs only reach the first server in arma/config.yml, so a --server-id run of any other one " \
              "will not answer."
      end

      connection_server.pause
      retry
    end

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
