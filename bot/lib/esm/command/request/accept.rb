# frozen_string_literal: true

module ESM
  module Command
    module Request
      class Accept < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # Required: Duh
        argument :uuid, required: true, checked_against: /[0-9a-fA-F]{4}/

        #
        # Configuration
        #

        change_attribute :enabled, modifiable: false
        change_attribute :allowed_in_text_channels, default: false
        change_attribute :allowlist_enabled, modifiable: false

        command_type :player

        #################################

        def on_execute
          request = current_user.pending_requests.where(uuid_short: arguments.uuid).first
          check_for_request!(request)
          request.respond(true)
        end

        private

        def check_for_request!(request)
          raise_error!(:invalid_request_id, user: current_user.mention) if request.nil?
        end
      end
    end
  end
end
