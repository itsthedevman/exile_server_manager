# frozen_string_literal: true

module ESM
  class Server
    def delete_all_territories
      sqf = <<~SQF
        ExileLocations = [];
        { deleteVehicle _x } forEach ("Exile_Construction_Flag_Static" allObjects 0);
      SQF

      execute_sqf!(sqf)
    end
  end
end
