# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Website API handler that runs a command the page is waiting on. Unlike {AsyncCommand} there is no
        # {ESM::ServiceCommand} row to look up, so the caller supplies the invoking user and community directly and the
        # command's reply is handed back as the RPC's result.
        #
        # The Arma round-trip blocks, so the work is offloaded to a Concurrent::Promise and the bot replies once it
        # resolves (see Server#respond_when_resolved), keeping the NATS dispatch thread free.
        #
        # @param command_name [String] The command to run, resolved through ESM::Command[]
        # @param user_id [Integer] The ESM database id of the player running the command
        # @param community_id [Integer] The ESM database id of the community the command was run from
        # @param arguments [Hash] The command's arguments, including the :server_id it targets
        #
        # @return [Concurrent::Promise] resolving to whatever the command replied with, or nil when it never replied
        #
        # @raise [ArgumentError] When the command, user, or community can't be resolved
        #
        class SyncCommand
          def self.call(command_name:, user_id:, community_id:, arguments: {})
            command_class = ESM::Command[command_name]
            raise ArgumentError, "Unknown command: #{command_name}" if command_class.nil?

            user = ESM::User.find_by(id: user_id)
            raise ArgumentError, "Unknown player: #{user_id}" if user.nil?

            community = ESM::Community.find_by(id: community_id)
            raise ArgumentError, "Unknown community: #{community_id}" if community.nil?

            event = Datum.new(user:, community:, arguments:)

            Concurrent::Promise.execute do
              ESM::Database.with_connection do
                command_class.website_sync_hook(event)
              end
            end
          end
        end
      end
    end
  end
end
