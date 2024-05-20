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

  before do |example|
    ESM.redis.del("server_key_set")

    next unless example.metadata[:requires_connection]

    # Store the server key so the build tool can pick it up and write it
    ESM.redis.set("server_key", server.token.to_json)

    connection_server.resume

    wait_for { ESM.redis.exists?("server_key_set") }.to be(true)

    wait_for { server.reload.connected? }.to be(true),
      "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    # This allows us to run commands on the server without spawning in
    allow_any_instance_of(ESM::User).to receive(:create_account) do |user|
      next if ESM::ExileAccount.where(uid: user.steam_uid).exists?

      ESM::ExileAccount.from(user)
    end

    allow_any_instance_of(ESM::User).to receive(:create_player) do |user|
      next if ESM::ExilePlayer.where(account_uid: user.steam_uid).exists?

      ESM::ExilePlayer.from(user)
    end

    # This allows us to "spawn" players on the server
    # All this does is spawns a bambi and assigns player variables so the bambi AI
    # can be treated as a player
    allow_any_instance_of(ESM::User).to receive(:connect) do |user, **attrs|
      user.create_account
      user.create_player

      spawn_test_user(user, on: server, **attrs)
      _spawned_players << user
    end

    # Clear any territories
    server.delete_all_territories
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

  def spawn_test_user(user, **attrs)
    attributes = {
      damage: 0,
      hunger: 100,
      thirst: 100,
      alcohol: 0,
      oxygen_remaining: 1,
      bleeding_remaining: 0,
      hitpoints: [["face_hub", 0], ["neck", 0], ["head", 0], ["pelvis", 0], ["spine1", 0], ["spine2", 0], ["spine3", 0], ["body", 0], ["arms", 0], ["hands", 0], ["legs", 0], ["body", 0]],
      direction: 0,
      position_x: 0,
      position_y: 0,
      position_z: 0,
      assigned_items: [],
      backpack: "",
      backpack_items: [],
      backpack_magazines: [],
      backpack_weapons: [],
      current_weapon: "",
      goggles: "",
      handgun_items: ["", "", "", ""],
      handgun_weapon: "",
      headgear: "",
      binocular: "",
      loaded_magazines: [],
      primary_weapon: "",
      primary_weapon_items: ["", "", "", ""],
      secondary_weapon: "",
      secondary_weapon_items: [],
      uniform: "",
      uniform_items: [],
      uniform_magazines: [],
      uniform_weapons: [],
      vest: "",
      vest_items: [],
      vest_magazines: [],
      vest_weapons: [],
      account_money: 0,
      account_score: 0,
      account_kills: 0,
      account_deaths: 0,
      clan_id: "",
      clan_name: "",
      temperature: 37,
      wetness: 0,
      account_locker: 0
    }

    attributes.each { |key, value| attributes[key] = attrs[key] || value }

    # Offset the unused values
    data = ["", "", ""] + attributes.values

    sqf = <<~SQF
      private _data = #{data};
      private _pos2D = (call ExileClient_util_world_getAllAirportPositions) select 0;

      _data set [11, _pos2D select 0];
      _data set [12, _pos2D select 1];

      [_data, objNull, "#{user.steam_uid}", 0] call ExileServer_object_player_database_load;
      _createdPlayer = ([_pos2D select 0, _pos2D select 1, 0] nearEntities ["Exile_Unit_Player", 100]) select 0;
      if (isNil "_createdPlayer") exitWith {};

      ESM_TestUser_#{user.steam_uid} = _createdPlayer;
      _createdPlayer allowDamage false;
      _createdPlayer setDamage 0;

      netId _createdPlayer
    SQF

    net_id = execute_sqf!(sqf)
    expect(net_id).not_to be_nil

    user.connected = true
    net_id
  end

  def make_territory_admin!(user)
    # Arma vomits unless we return something like `nil`
    execute_sqf!("ESM_TerritoryAdminUIDs = [#{user.steam_uid.quoted}]; nil")
  end
end
