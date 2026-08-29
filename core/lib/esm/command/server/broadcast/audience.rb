# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Broadcast < ApplicationCommand
        ##
        # Who a broadcast reaches, for a given set of servers.
        #
        # Membership is derived, never chosen: a player is in the audience because they have run a command for one of
        # the servers, which is the only record ESM keeps of who plays where. Anyone who has turned custom
        # notifications off for a server drops out of that server's slice.
        #
        class Audience
          ##
          # The users a broadcast to these servers would reach, one entry per Discord account.
          #
          # Deduplication is why this is one shared thing rather than a query at each call site: someone who plays on
          # three of a community's servers is a single recipient, so the size of this is a union and never the sum of
          # the per-server counts. Anything that shows an audience size has to derive it from here, or the number
          # shown and the number actually messaged will disagree.
          #
          # @param servers [Enumerable<ESM::Server>] the servers being broadcast to
          #
          # @return [Array<ESM::User>]
          #
          def self.for(servers)
            new(servers).users
          end

          def initialize(servers)
            @servers = servers
          end

          def users
            servers.flat_map { |server| users_for(server) }.compact.uniq(&:discord_id)
          end

          private

          attr_reader :servers

          # A player can be on a cooldown row by user id, by steam uid, or by both, depending on whether they were
          # registered when they ran the command, so both columns have to be followed back to accounts. Only those two
          # columns are read rather than whole rows - a long-running server's cooldown table is large and none of the
          # rest of it is wanted.
          def users_for(server)
            denied_user_ids = ESM::UserNotificationPreference.where(server_id: server.id, custom: false).pluck(:user_id)
            denied_steam_uids = ESM::User.where(id: denied_user_ids).pluck(:steam_uid).compact

            played_here = ESM::Cooldown
              .where(server_id: server.id)
              .where.not(user_id: denied_user_ids, steam_uid: denied_steam_uids)
              .pluck(:user_id, :steam_uid)
              .uniq

            user_ids = played_here.map(&:first).compact.uniq
            steam_uids = played_here.map(&:second).compact.uniq

            ESM::User.where(id: user_ids).or(ESM::User.where(steam_uid: steam_uids))
          end
        end
      end
    end
  end
end
