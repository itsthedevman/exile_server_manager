# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Website API handler that dispatches a persisted {ESM::ServerCommand} into the command
        # lifecycle. Looks the row up by id and runs its command on a background promise so the web
        # request doesn't block on the round-trip out to Arma.
        #
        class ServerCommand
          def self.call(command_id:)
            command = ESM::ServerCommand.includes(:user, :server, :community).find_by(id: command_id)
            raise ArgumentError, "Unknown command: #{command_id}" if command.nil?

            Concurrent::Promise.execute do
              ESM::Database.with_connection do
                command.command_class.website_event_hook(command)
              end
            end
          end
        end
      end
    end
  end
end
