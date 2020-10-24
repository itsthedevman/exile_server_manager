# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Player < ESM::Command::Base
        type :admin
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :target
        argument :type, regex: /^m(?:oney)?|^r(?:espect)?|^l(?:ocker)?|^h(?:eal)?|^k(?:ill)?/, description: "commands.player.arguments.type"
        argument :value,
          regex: /-?\d+/,
          description: "commands.player.arguments.value",
          before_parse: lambda { |parser|
            return if !@arguments.type.match(/^h(?:eal)?|^k(?:ill)?/i)

            # The types `heal` and `kill` don't require the value argument.
            # This is done this way because setting `value` to have a default of nil makes the help text confusing
            parser.argument.default = nil
          }

        def discord
          @checks.registered_target_user! if target_user.is_a?(Discordrb::User)

          deliver!(
            function_name: "modifyPlayer",
            discord_tag: current_user.mention,
            target_uid: target_uid,
            type: expand_type,
            value: @arguments.value
          )
        end

        def server
          embed = ESM::Notification.build_random(
            community_id: target_community.id,
            type: expand_type,
            category: "player",
            serverid: target_server.server_id,
            servername: target_server.server_name,
            communityid: target_community.community_id,
            username: current_user.username,
            usertag: current_user.mention,
            targetusername: target_user.username,
            targetusertag: target_user.mention,
            targetuid: target_uid,
            modifiedamount: @response.modified_amount&.to_readable,
            previousamount: @response.previous_amount&.to_readable,
            newamount: @response.new_amount&.to_readable
          )

          reply(embed)
        end

        private

        def expand_type
          @expand_type ||= lambda do
            case @arguments.type
            when "m"
              "money"
            when "r"
              "respect"
            when "l"
              "locker"
            when "h"
              "heal"
            when "k"
              "kill"
            else
              @arguments.type
            end
          end.call
        end
      end
    end
  end
end
