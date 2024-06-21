# frozen_string_literal: true

module ESM
  class Server
    def reset!
      sqf = [
        delete_all_users,
        delete_all_territories
      ]

      execute_sqf!(sqf.join("\n"))
    end

    def delete_all_users
      <<~SQF
        { deleteVehicle _x } forEach ([0, 0, 0] nearEntities ["Exile_Unit_Player", 1000000]);
      SQF
    end

    def delete_all_territories
      <<~SQF
        ExileLocations = [];
        { deleteVehicle _x } forEach ("Exile_Construction_Flag_Static" allObjects 0);
      SQF
    end
  end
end
