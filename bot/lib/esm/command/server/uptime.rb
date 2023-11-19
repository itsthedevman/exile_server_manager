# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Uptime < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :for

        #
        # Configuration
        #

        command_type :player

        does_not_require :registration

        #################################

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.uptime.server_uptime", server: target_server.server_id, time: target_server.uptime)
            end

          reply(embed)
        end
      end
    end
  end
end
