# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Runs the territory payment for a website-initiated ServerCommand.
        #
        # Acks receipt immediately and runs the Arma round-trip off-thread via
        # ServerCommand#execute, which records the terminal status on the shared row
        # the website reads for the result. The acting player and target server come
        # from the row, which the website populates from the session.
        #
        # @return [ESM::ServerCommand] the command being executed.
        #
        class TerritoryPay
          def self.call(command_id:)
            command = ESM::ServerCommand.includes(:user, :server).find_by(id: command_id)
            raise ArgumentError, "Unknown command: #{command_id}" if command.nil?

            command.execute do
              command.server.call_sqf_function!(
                "ESMs_command_pay",
                territory_id: command.arguments[:territory_id],
                player: command.user
              )
            end
          end
        end
      end
    end
  end
end
