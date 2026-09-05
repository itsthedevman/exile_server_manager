# frozen_string_literal: true

describe "ESMs_object_vehicle_spawnReward", :requires_connection, v2: true do
  include_context "connection"

  let(:vehicle_class) { "Exile_Car_Hatchback_Rusty1" }
  let(:spawn_location) { "nearby" }
  let(:territory_id) { -1 }

  let!(:net_id) do
    user.exile_account
    spawn_player_for(user)
  end

  # Every test player spawns at [0, 0, 0] since exile_player's position columns default to zero, and on any map that
  # corner is ocean. Nearby delivery searches 250m for somewhere to put a vehicle, so it needs the player on land.
  before do
    execute_sqf!(
      <<~SQF
        private _playerObject = objectFromNetId "#{net_id}";
        private _position = [getPosATL _playerObject, 0, 5000, 15, 0, 0.3, 0] call BIS_fnc_findSafePos;

        _playerObject setPosATL [_position select 0, _position select 1, 0];
        true
      SQF
    )
  end

  subject(:result) do
    execute_sqf!(
      <<~SQF
        private _playerObject = objectFromNetId "#{net_id}";

        private _vehicle = createHashMapFromArray [
          ["class_name", "#{vehicle_class}"],
          ["spawn_location", "#{spawn_location}"],
          ["territory_id", #{territory_id}]
        ];

        [_playerObject, "#{user.steam_uid}", _vehicle] call ESMs_object_vehicle_spawnReward
      SQF
    )
  end

  # The world persists between examples, so a delivered vehicle is still parked there for the next one
  after do
    execute_sqf!(
      <<~SQF
        {
          deleteVehicle _x
        } forEach (nearestObjects [objectFromNetId "#{net_id}", ["#{vehicle_class}"], 300]);

        true
      SQF
    )
  end

  context "when the class name is not a vehicle on this server" do
    let(:vehicle_class) { "Not_A_Real_Vehicle_Class" }

    it "reports invalid_class and falls back to the class name" do
      delivered, reason, display_name, pin_code = result

      expect(delivered).to be(false)
      expect(reason).to eq("invalid_class")
      expect(display_name).to eq(vehicle_class)
      expect(pin_code).to eq("")
    end
  end

  context "when the spawn location needs the player to pick" do
    let(:spawn_location) { "player_decides" }

    it "reports unsupported_location" do
      delivered, reason, display_name, pin_code = result

      expect(delivered).to be(false)
      expect(reason).to eq("unsupported_location")
      expect(display_name).to eq("Hatchback")
      expect(pin_code).to eq("")
    end
  end

  # Read from the running server rather than hardcoded
  def garage_capacity_for(level)
    execute_sqf!(
      <<~SQF
        (getArray(missionConfigFile >> "CfgVirtualGarage" >> "numberOfVehicles")) select ((#{level} - 1) max 0)
      SQF
    )
  end

  # Exile stores the level and the vehicle list on the flag object, and spawnReward reads both from there, so a spec
  # can set up any capacity scenario without touching the territory's database row.
  def configure_garage!(level:, stored_count: 0)
    execute_sqf!(
      <<~SQF
        private _flagObject = #{territory.id} call ESMs_system_territory_get;
        if (isNull _flagObject) exitWith { false };

        private _stored = [];
        for "_i" from 1 to #{stored_count} do
        {
          _stored pushBack ["#{vehicle_class}", format["filler_%1", _i]];
        };

        _flagObject setVariable ["ExileTerritoryLevel", #{level}, true];
        _flagObject setVariable ["ExileTerritoryStoredVehicles", _stored, true];
        true
      SQF
    )
  end

  def stored_vehicles
    execute_sqf!(
      <<~SQF
        private _flagObject = #{territory.id} call ESMs_system_territory_get;
        if (isNull _flagObject) exitWith { [] };

        _flagObject getVariable ["ExileTerritoryStoredVehicles", []]
      SQF
    )
  end

  context "when spawning nearby" do
    it "delivers the vehicle and returns a generated pin" do
      delivered, reason, display_name, pin_code = result

      expect(delivered).to be(true)
      expect(reason).to eq("")
      expect(display_name).to eq("Hatchback")
      expect(pin_code).to match(/\A\d{4}\z/)
    end

    it "spawns it owned by the player and unlocked" do
      # Referenced before the query so the vehicle exists to be found
      expect(result.first).to be(true)

      owner_uid, access_code, is_persistent = execute_sqf!(
        <<~SQF
          private _playerObject = objectFromNetId "#{net_id}";
          private _vehicles = nearestObjects [_playerObject, ["#{vehicle_class}"], 300];

          if (count(_vehicles) isEqualTo 0) exitWith { ["", "", false] };

          private _vehicleObject = _vehicles select 0;

          [
            _vehicleObject getVariable ["ExileOwnerUID", ""],
            _vehicleObject getVariable ["ExileAccessCode", ""],
            _vehicleObject getVariable ["ExileIsPersistent", false]
          ]
        SQF
      )

      expect(owner_uid).to eq(user.steam_uid)
      expect(access_code).to eq(result[3])
      expect(is_persistent).to be(true)
    end
  end

  context "when storing into a virtual garage" do
    let(:spawn_location) { "virtual_garage" }
    let(:territory_id) { territory.id }

    # Level 2 is the first with a garage in Exile's shipped config, but the capacity is read back rather than assumed
    let(:level_with_garage) { 2 }

    before { territory.create_flag }

    context "when the territory has no flag on the server" do
      let(:territory_id) { 999_999 }

      it "reports territory_not_found" do
        delivered, reason = result

        expect(delivered).to be(false)
        expect(reason).to eq("territory_not_found")
      end
    end

    context "when the territory's level has no garage" do
      before { configure_garage!(level: 1) }

      it "reports no_garage" do
        expect(garage_capacity_for(1)).to eq(-1)

        delivered, reason = result

        expect(delivered).to be(false)
        expect(reason).to eq("no_garage")
      end
    end

    context "when the garage is already full" do
      before { configure_garage!(level: level_with_garage, stored_count: garage_capacity_for(level_with_garage)) }

      it "reports garage_full" do
        delivered, reason = result

        expect(delivered).to be(false)
        expect(reason).to eq("garage_full")
      end
    end

    context "when the garage has room" do
      before { configure_garage!(level: level_with_garage) }

      it "delivers the vehicle and returns a generated pin" do
        delivered, reason, display_name, pin_code = result

        expect(delivered).to be(true)
        expect(reason).to eq("")
        expect(display_name).to eq("Hatchback")
        expect(pin_code).to match(/\A\d{4}\z/)
      end

      it "adds it to the flag's stored vehicles and leaves nothing in the world" do
        expect(result.first).to be(true)

        # Exile stores [class, nickname] pairs, which execute_sqf! reads back as a hashmap
        expect(stored_vehicles).to eq(vehicle_class => "Hatchback")

        remaining = execute_sqf!(
          <<~SQF
            private _flagObject = #{territory.id} call ESMs_system_territory_get;
            count(nearestObjects [_flagObject, ["#{vehicle_class}"], 200])
          SQF
        )

        expect(remaining).to eq(0)
      end
    end
  end
end
