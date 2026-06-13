# frozen_string_literal: true

module ESM
  module Website
    class API
      module Handlers
        ##
        # Returns the community's text channels grouped by category, filtered to
        # channels the bot (and optional user) can read/send in. Format matches
        # what the website's channel picker expects.
        #
        class CommunityChannels
          def self.call(id:, user_id:, **)
            community = ESM::Community.find_by(id: id)
            return if community.nil?

            server = community.discord_server
            return if server.nil?

            user = ESM::User.find_by(id: user_id)

            channels = server.channels.filter_map do |channel|
              bot_can_read = ESM.discord_bot.channel_permission?(:send_messages, channel)
              user_can_read = true
              user_can_read = user.channel_permission?(:read_messages, channel) if user
              next unless bot_can_read && user_can_read

              channel.to_h
            rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
              # Skip channels the bot can't introspect (lost access mid-list).
              nil
            end

            channels.sort_by! { |c| c[:position] || 0 }

            grouped_channels = channels.filter_map do |category_channel|
              next unless category_channel[:type] == :category

              children = channels.select do |channel|
                channel[:type] == :text && channel.dig(:category, :id) == category_channel[:id]
              end

              [category_channel, children]
            end

            not_categorized_channels = channels.select { |channel| channel[:type] == :text && channel[:category].nil? }
            grouped_channels.unshift([{name: community.community_name}, not_categorized_channels])

            grouped_channels
          rescue Discordrb::Errors::CodeError, Discordrb::Errors::NoPermission
            # Bot can't read the guild's channel list at all. Caller sees nil.
            nil
          end
        end
      end
    end
  end
end
