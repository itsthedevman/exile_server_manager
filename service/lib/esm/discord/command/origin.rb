# frozen_string_literal: true

module ESM
  module Discord
    module Command
      ##
      # Discord adapter for {ESM::Command::Origin}. Holds the user, community, and channel
      # hydrated from a Discordrb application command event so the command lifecycle can
      # reply and identify the caller without referencing discordrb directly.
      #
      class Origin < ESM::Command::Origin
        attr_reader :current_user, :current_community, :current_channel

        def initialize(user:, community: nil, channel: nil)
          @current_user = user
          @current_community = community
          @current_channel = channel
          @source = :discord
        end

        def reply(content)
          ESM.discord_bot.deliver(content, to: @current_channel, block: true)
        end

        def log_context
          {
            author: "#{@current_user&.distinct} (#{@current_user&.discord_id})",
            channel: channel_label
          }
        end

        private

        def channel_label
          return "(no channel)" if @current_channel.nil?

          type_name = Discordrb::Channel::TYPE_NAMES[@current_channel.type]
          "#{type_name} (#{@current_channel.id})"
        end
      end
    end
  end
end
