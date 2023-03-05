# frozen_string_literal: true

module ESM
  module Command
    module Server
      class SetId < ESM::Command::Base
        set_type :player
        register_aliases :setterritoryid, :setid
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :old_territory_id, template: :territory_id
        argument :new_territory_id, template: :territory_id, description: "commands.set_id.arguments.new_territory_id"

        def on_execute
          # Require at least 3 characters and a max of 30
          check_for_minimum_characters!
          check_for_maximum_characters!

          # Set the request
          deliver!(
            command_name: "setterritoryid",
            query: "set_custom_territory_id",
            player_uid: current_user.steam_uid,
            old_territory_id: @arguments.old_territory_id,
            new_territory_id: @arguments.new_territory_id
          )
        end

        def on_response(_, _)
          check_for_failure!
          reply(success_message)
        end

        private

        def check_for_minimum_characters!
          return if @arguments.new_territory_id.nil?

          check_failed!(:minimum_characters, user: current_user.mention) if @arguments.new_territory_id.size < 3
        end

        def check_for_maximum_characters!
          return if @arguments.new_territory_id.nil?

          check_failed!(:maximum_characters, user: current_user.mention) if @arguments.new_territory_id.size > 20
        end

        def check_for_failure!
          return if @response.success

          # Don't set a cooldown if we errored.
          skip(:cooldown)

          # DLL Reason. This is a weird one since I can't localize the message
          check_failed! { ESM::Embed.build(:error, description: "I'm sorry #{current_user.mention}, #{@response.reason}") } if @response.reason

          check_failed!(:access_denied, user: current_user.mention)
        end

        def success_message
          ESM::Embed.build(
            :success,
            description: I18n.t(
              "commands.set_id.success_message",
              prefix: prefix,
              server_id: target_server.server_id,
              old_territory_id: @arguments.old_territory_id,
              new_territory_id: @arguments.new_territory_id
            )
          )
        end
      end
    end
  end
end
