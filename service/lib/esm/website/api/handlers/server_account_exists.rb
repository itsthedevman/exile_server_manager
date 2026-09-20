# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Whether a server has ever seen a player, which is what the dashboard asks before offering anything that acts
        # on their character.
        #
        # A database read rather than a command: every feature on the page belongs to a command a community can switch
        # off, and "have you played here" has to be answerable whatever they have enabled.
        #
        # @param server_id [Integer] The ESM database id of the server to ask
        # @param steam_uid [String] The player's Steam UID
        #
        # @return [Boolean, nil] whether the server knows them, or nil when the server can't be reached
        #
        class ServerAccountExists
          def self.call(server_id:, steam_uid:, **)
            server = ESM::Server.find_by(id: server_id)
            raise ArgumentError, "Unknown server: #{server_id}" if server.nil?

            return if steam_uid.blank?

            accounts = server.run_database_query!("account_exists", uid: steam_uid)
            accounts.present?
          rescue ESM::Exception::ServerNotConnected, ESM::Exception::RequestTimeout
            nil
          end
        end
      end
    end
  end
end
