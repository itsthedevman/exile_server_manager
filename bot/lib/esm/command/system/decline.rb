# frozen_string_literal: true

module ESM
  module Command
    module System
      class Decline < ESM::Command::Base
        type :player
        limit_to :dm

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :uuid, regex: /[0-9a-fA-F]{4}/, description: "commands.decline.arguments.uuid"

        def discord
          request = current_user.esm_user.pending_requests.where(uuid_short: @arguments.uuid).first
          check_for_request!(request)
          request.respond(false)

          ESM::Embed.build(:success, description: I18n.t("commands.decline.success_message"))
        end

        module ErrorMessage
          def self.invalid_request_id(user:)
            I18n.t("commands.decline.error_message.invalid_request_id", user: user.mention)
          end
        end

        #########################
        # Command Methods
        #########################
        def check_for_request!(request)
          raise ESM::Exception::CheckFailure, error_message(:invalid_request_id, user: current_user) if request.nil?
        end
      end
    end
  end
end
