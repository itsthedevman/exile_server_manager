# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Runs a website-initiated gamble for a ServerCommand.
        #
        # Acks receipt immediately and runs the Arma round-trip off-thread via
        # ServerCommand#execute, which stores the bet payload and terminal status on
        # the shared row the website polls. The bet is recorded against the player's
        # UserGambleStat here, exactly once, so a re-poll of the row can't double it.
        #
        # @return [ESM::ServerCommand] the command being executed.
        #
        class ServerGamble
          def self.call(command_id:)
            command = ESM::ServerCommand.includes(:user, :server).find_by(id: command_id)
            raise ArgumentError, "Unknown command: #{command_id}" if command.nil?

            command.execute do
              data = command.server.call_sqf_function!(
                "ESMs_command_gamble",
                amount: command.arguments[:amount],
                player: command.user
              ).data

              ESM::UserGambleStat
                .find_or_create_by(user_id: command.user.id, server_id: command.server.id)
                .record!(win: data.win, amount_changed: data.amount.to_i)

              {win: data.win, amount: data.amount.to_i, locker_after: data.locker_after.to_i}
            end
          end
        end
      end
    end
  end
end
