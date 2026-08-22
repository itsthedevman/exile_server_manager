# frozen_string_literal: true

module ESM
  class User
    attr_accessor :role_id, :connected
    attr_reader :net_id

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
    def connect_to(server)
      # Ensure these exist
      exile_account
      exile_player

      spawn_test_user(server)
    end

    def spawn_test_user(server)
      sqf = <<~SQF
        private _data = "loadPlayer:#{steam_uid}" call ExileServer_system_database_query_selectSingle;

        [_data, objNull, #{steam_uid.in_quotes}, #{SecureRandom.hex(4).in_quotes}] call ExileServer_object_player_database_load;
        _createdPlayer = #{steam_uid.in_quotes} call ExileClient_util_player_objectFromPlayerUID;
        if (isNull _createdPlayer) exitWith { nil };
        
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
