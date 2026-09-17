# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Territory < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # See Argument::TEMPLATES[:territory_id]
        argument :territory_id, display_name: :territory

        #
        # Configuration
        #

        change_attribute :allowed_in_text_channels, default: false

        command_namespace :server, :my, command_name: :territory
        command_type :player

        #################################

        def on_execute
          territory = requested_territory

          # An ID that matches no territory never reaches here - the extension raises territory_id_does_not_exist
          # first. Nothing found at this point means the territory exists but the player simply isn't a member
          if territory.nil?
            raise_error!(
              :not_a_member,
              user: current_user,
              territory_id: arguments.territory_id,
              server_id: target_server.server_id
            )
          end

          embed = ESM::Exile::Territory.new(server: target_server, territory: territory.to_h).to_embed
          reply(embed)
        end

        def on_website_execute
          # Nothing found is a valid answer here - the page renders its own unavailable state - so unlike the Discord
          # path this hands back nil rather than raising.
          reply(requested_territory)
        end

        module V1
          def on_execute
            raise_server_version_not_supported!
          end
        end

        private

        def requested_territory
          query_exile_database!(
            "territory_info",
            territory_id: arguments.territory_id,
            requesting_uid: current_user.steam_uid
          ).first
        end
      end
    end
  end
end
