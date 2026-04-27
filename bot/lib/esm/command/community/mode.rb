# frozen_string_literal: true

module ESM
  module Command
    module Community
      class Mode < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:community_id]
        argument :community_id, display_name: :for

        #
        # Configuration
        #

        change_attribute :allowed_in_text_channels, modifiable: false, default: false
        change_attribute :cooldown_time, modifiable: false
        change_attribute :enabled, modifiable: false
        change_attribute :allowlist_enabled, modifiable: false
        change_attribute :allowlisted_role_ids, modifiable: false

        command_namespace :community, :admin, command_name: :change_mode
        command_type :admin

        does_not_require :registration

        limit_to :dm

        #################################

        def on_execute
          check_for_owner!

          enable_player_mode = !target_community.player_mode_enabled?
          check_for_active_servers! if enable_player_mode

          # Flip it, flip it good
          target_community.update!(player_mode_enabled: enable_player_mode)

          # Reply back
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t(
                "commands.mode.#{enable_player_mode ? "enabled" : "disabled"}",
                community_name: target_community.name
              )
              e.color = :green
            end

          reply(embed)
        end

        private

        def check_for_active_servers!
          raise_error!(:servers_exist, user: current_user.mention) if target_community.servers.any?
        end
      end
    end
  end
end
