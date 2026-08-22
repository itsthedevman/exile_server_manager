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

    # Arma keeps the world between examples while every test player spawns on the same spot (exile_player's position
    # columns all default to 0), so loot dropped by one example is still lying there for the next one to find. Clear
    # it on the way in, or anything reading holders near the player reads the whole suite's history.
    clear_loot_holders_near!(net_id)

    net_id
  end

  def clear_loot_holders_near!(net_id, radius: 25)
    server.execute_sqf! <<~SQF
      private _playerObject = objectFromNetId "#{net_id}";
      if (isNull _playerObject) exitWith { false };

      {
        deleteVehicle _x
      } forEach (
        nearestObjects [
          _playerObject,
          ["GroundWeaponHolder", "WeaponHolderSimulated", "LootWeaponHolder"],
          #{radius}
        ]
      );

      true
    SQF
  end

  def get_player_variable!(net_id, variable, default = nil)
    server.execute_sqf! <<~SQF
      private _playerObject = objectFromNetId "#{net_id}";
      if (isNull(_playerObject)) exitWith { nil };

      _playerObject getVariable ["#{variable}", #{default.to_json}]
    SQF
  end

  # Reads every named variable off a territory's flag object in one round trip. Each read is a TCP call into Arma
  # and the flag checks want several variables at a time, so they are asked for together rather than one by one.
  #
  # An unset variable comes back as nil, as does every variable when the territory has no flag in game. Check the
  # flag exists (ExileTerritory#create_flag) before treating a nil as the command's doing.
  def get_territory_variables!(territory_id, *variables)
    # Stands in for an unset variable on the way home: getVariable needs a real default value, and an array carrying
    # a nil element does not survive the trip.
    unset = "__unset__"

    values = server.execute_sqf! <<~SQF
      private _territory = #{territory_id} call ESMs_system_territory_get;
      if (isNull _territory) exitWith { nil };

      #{variables.to_json} apply { _territory getVariable [_x, #{unset.to_json}] }
    SQF

    values ||= []

    variables.zip(values).to_h { |variable, value| [variable, (value == unset) ? nil : value] }
  end

  def get_territory_variable!(territory_id, variable)
    get_territory_variables!(territory_id, variable)[variable]
  end

  # Everything the player is carrying, as a flat list of classnames: what is on them, in their containers, and the
  # containers themselves.
  #
  # An empty slot reads as "" and an empty string does not survive the trip home - it comes back mangled and takes
  # the whole payload's JSON with it - so the blanks are dropped in SQF rather than in Ruby.
  #
  # Magazines come from magazinesAmmoFull rather than magazines: one loaded into a weapon belongs to the player just
  # as much as one sitting in their uniform, and `magazines` leaves it out.
  def get_player_cargo!(net_id)
    cargo = server.execute_sqf! <<~SQF
      private _playerObject = objectFromNetId "#{net_id}";
      if (isNull _playerObject) exitWith { nil };

      private _worn = [uniform _playerObject, vest _playerObject, backpack _playerObject];

      private _magazines = magazinesAmmoFull _playerObject apply { _x select 0 };

      (items _playerObject + _magazines + weapons _playerObject + _worn) select { _x != "" }
    SQF

    cargo || []
  end

  # The loot holders sitting near a player, each as a flat list of the classnames it holds.
  #
  # The command searches 3 meters when deciding whether to reuse a holder; this looks a little wider because a
  # spawned player is free to drift away from where the holder was dropped.
  def nearby_loot_holders!(net_id, radius: 5)
    holders = server.execute_sqf! <<~SQF
      private _playerObject = objectFromNetId "#{net_id}";
      if (isNull _playerObject) exitWith { nil };

      private _holders = nearestObjects [
        _playerObject,
        ["GroundWeaponHolder", "WeaponHolderSimulated", "LootWeaponHolder"],
        #{radius}
      ];

      _holders apply {
        (itemCargo _x + magazineCargo _x + weaponCargo _x + backpackCargo _x) select { _x != "" }
      }
    SQF

    holders || []
  end

  # Asserts the player's locker holds the expected amount in the database and, when the spec spawned them, on their
  # player object in game too. Exile only pushes the value onto the object for a connected player; an offline
  # player's locker lives solely in the database until they next join, so there is nothing in game to check.
  #
  # Whether to look in game comes from the spec having called spawn_player_for, not from the player's net id. A
  # spawn that failed leaves the net id nil, and reading intent off that would turn a broken spawn into a silently
  # skipped check rather than a failure.
  def expect_locker_to_eq(user, amount, message = nil)
    expect(user.exile_account.reload.locker).to eq(amount), message

    return unless _spawned_players.include?(user)

    # Polled rather than read once: the networked setVariable settles a frame or two after the command's response is
    # already back in Ruby, so a single read races it and loses on fast hardware.
    wait_for { get_player_variable!(user.net_id, "ExileLocker", -1) }.to eq(amount)
  end

  # Territory attributes a failing command must leave alone. A spec exercising failure paths overrides this, and the
  # territory error examples then check the territory came through untouched. Empty skips the check.
  let(:unchanged_territory_attributes) { [] }

  # Runs the block and asserts the territory came out of it untouched: the row still holds what it held, and the flag
  # still mirrors the row. Every ESM territory command throws from its validation section, before the block that
  # writes anything, so a failure that moves state means a throw has been added below the writes or the writes have
  # moved above the throws.
  #
  # Reading the row costs nothing, so an opted-in failure example pays for one flag read and nothing else. Pass
  # `flag: false` when the scenario has no flag in game to compare against.
  def expect_territory_unchanged(flag: true)
    return yield if unchanged_territory_attributes.blank?

    columns = unchanged_territory_attributes.map(&:to_s)
    before = territory.reload.slice(*columns)

    result = yield

    expect(territory.reload.slice(*columns)).to eq(before)
    expect_territory_flag_to_match_database(*unchanged_territory_attributes) if flag

    result
  end

  # Asserts the territory's flag object in game carries the same values as its database row.
  #
  # A territory command writes its changes to two places that can drift apart: the flag, so the change takes effect
  # for anyone standing in the territory right now, and the territory table, so it survives a restart. This says
  # nothing about either value being *correct* - assert the expected value against the row as well.
  def expect_territory_flag_to_match_database(*attributes)
    territory.reload

    # Membership is a set, so the flag is not required to carry it in the row's order.
    expected = territory.arma_variables_for(*attributes).transform_values do |value|
      value.is_a?(Array) ? match_array(value) : eq(value)
    end

    # Polled rather than read once: territory variables are broadcast with setVariable's public flag, so they settle
    # a frame or two after the command's response is already back in Ruby, and a single read loses that race on fast
    # hardware.
    wait_for { get_territory_variables!(territory.id, *expected.keys) }.to match(expected)
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
