# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Reward < ESM::Command::Base
        type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        # Check for pending requests
        # Check for rewards
        # Add request
        # Send request message
        #
        # Accepted
        # Send waiting message and request server for rewards
        #
        # Server
        # @response.receipt <- JSON
        # receipt [item, quantity]
        def discord
          @checks.pending_request!

          add_request

          send_request_message(
            description: I18n.t(
              "commands.add.request_description",
              current_user: current_user.distinct,
              target_user: target_user.mention,
              territory_id: @arguments.territory_id,
              server_id: target_server.server_id
            )
          )

          embed = ESM::Embed.build(
            :success,
            description: I18n.t("commands.request.sent", uuid: request.uuid_short, user: target_user.distinct)
          )

          reply(embed)
        end

        def server; end

        def request_accepted(request); end

        def request_declined(request); end
      end
    end
  end
end
