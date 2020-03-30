# frozen_string_literal: true

module ESM
  module Command
    module Server
      class SetId < ESM::Command::Base
        type :player
        aliases :setterritoryid, :setid
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :old_territory_id, template: :territory_id
        argument :new_territory_id, template: :territory_id, description: "commands.set_id.arguments.new_territory_id"

        def discord
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

        def server
          check_for_failure!
          reply(success_message)
        end

        module ErrorMessage
          def self.minimum_characters(user:)
            I18n.t("commands.set_id.error_message.minimum_characters", user: user)
          end

          def self.maximum_characters(user:)
            I18n.t("commands.set_id.error_message.maximum_characters", user: user)
          end

          def self.access_denied(user:)
            I18n.t("commands.set_id.error_message.access_denied", user: user)
          end

          # DLL error messages can't be localized
          def self.dll_reason(user:, reason:)
            "I'm sorry #{user}, #{reason}"
          end
        end

        private

        def check_for_minimum_characters!
          return if @arguments.new_territory_id.nil?

          raise ESM::Exception::CheckFailure, error_message(:minimum_characters, user: current_user.mention) if @arguments.new_territory_id.size < 3
        end

        def check_for_maximum_characters!
          return if @arguments.new_territory_id.nil?

          raise ESM::Exception::CheckFailure, error_message(:maximum_characters, user: current_user.mention) if @arguments.new_territory_id.size > 30
        end

        def check_for_failure!
          return if @response.success

          # Don't set a cooldown if we errored.
          skip(:cooldown)

          # DLL Reason
          raise ESM::Exception::CheckFailure, error_message(:dll_reason, user: current_user.mention, reason: @response.reason) if @response.reason

          raise ESM::Exception::CheckFailure, error_message(:access_denied, user: current_user.mention)
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
