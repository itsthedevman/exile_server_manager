# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Resolves a Discord channel by ID, scoped by optional community/user filters,
        # and returns its serialized form when the bot has send access.
        #
        class Channel
          def self.call(id:, **filters)
            info!(event: "channel", id: id, filters: filters)

            channel = ESM.discord_bot.channel(id)
            return if channel.nil?
            return unless ESM.discord_bot.channel_permission?(:send_messages, channel)

            if (community_id = filters[:community_id])
              community = ESM::Community.find_by(id: community_id)
              return if community.nil?
              return unless channel.server.id.to_s == community.guild_id
            end

            if (user_id = filters[:user_id])
              user = ESM::User.find_by(id: user_id)
              return if user.nil?
              return unless user.channel_permission?(:read_messages, channel)
            end

            channel.to_h
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot was kicked from the guild that owns this channel, or the
            # channel/user disappeared between cache and lookup. Treat as
            # "channel not accessible" so the caller sees the same nil it
            # gets for any other missing channel.
            nil
          end
        end
      end
    end
  end
end
