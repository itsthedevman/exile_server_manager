# frozen_string_literal: true

module ESM
  class User
    attr_accessor :guild_type, :role_id, :connected

    def deregister!
      update!(steam_uid: nil)
    end

    def exile_account
      @exile_account ||= ESM::ExileAccount.from(self)
    end

    def exile_player
      @exile_player ||= ESM::ExilePlayer.from(self)
    end

    def kill_player!(server)
      exile_player.destroy!
      return unless @connected

      sqf = <<~SQF
        private _playerObject = objectFromNetId "#{@net_id}";
        _playerObject setDamage 666;
      SQF

      server.execute_sqf!(sqf)
    end

    # This allows us to "spawn" players on the server
    # All this does is spawns a bambi and assigns player variables so the bambi AI
    # can be treated as a player
    def connect_to(server, **player_attributes)
      # Ensure these exist
      exile_account
      exile_player

      spawn_test_user(server, **player_attributes)
    end

    def spawn_test_user(server, **player_attributes)
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
        account_money: exile_account.locker,
        account_score: exile_account.score,
        account_kills: exile_account.kills,
        account_deaths: exile_account.deaths,
        clan_id: "",
        clan_name: "",
        temperature: 37,
        wetness: 0,
        account_locker: exile_account.locker
      }

      attributes.each { |key, value| attributes[key] = player_attributes[key] || value }

      # Offset the unused values
      data = ["", "", ""] + attributes.values

      sqf = <<~SQF
        private _data = #{data};
        private _pos2D = (call ExileClient_util_world_getAllAirportPositions) select 0;

        _data set [11, _pos2D select 0];
        _data set [12, _pos2D select 1];

        [_data, objNull, "#{steam_uid}", 0] call ExileServer_object_player_database_load;
        _createdPlayer = ([_pos2D select 0, _pos2D select 1, 0] nearEntities ["Exile_Unit_Player", 100]) select 0;
        if (isNil "_createdPlayer") exitWith {};

        ESM_TestUser_#{steam_uid} = _createdPlayer;
        _createdPlayer allowDamage false;
        _createdPlayer setDamage 0;

        netId _createdPlayer
      SQF

      net_id = server.execute_sqf!(sqf)
      raise "Received a nil net ID from Arma when spawning in player" if net_id.nil?

      @connected = true
      @net_id = net_id
    end
  end
end
