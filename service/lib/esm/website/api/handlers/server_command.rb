# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        # TODO: Docs
        class ServerCommand
          def self.call(command_id:)
            command = ESM::ServerCommand.includes(:user).find_by(id: command_id)
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
