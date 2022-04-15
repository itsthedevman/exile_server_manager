# frozen_string_literal: true

module ESM
  module Command
    module System
      class Requests < ESM::Command::Base
        type :player
        aliases :pending_requests
        limit_to :dm

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        def discord
          requests = current_user.esm_user.pending_requests.select(:uuid, :uuid_short, :command_name, :requestor_user_id, :expires_at).order(:command_name)
          return send_no_requests_message if requests.blank?

          embed = ESM::Embed.build do |e|
            e.title = "Pending Requests"

            e.description = requests.map do |r|
              description = "`#{r.command_name}` - "
              description += "#{r.requestor.distinct} - " if current_user.esm_user.id != r.requestor_user_id # Performance optimization, only query if needed

              description + <<~STRING
                Expires on #{r.expires_at}
                [Accept](#{accept_request_url(r.uuid)}) - `#{prefix}accept #{r.uuid_short}`
                [Decline](#{decline_request_url(r.uuid)}) - `#{prefix}decline #{r.uuid_short}`
              STRING
            end.join("\n")
          end

          reply(embed)
        end

        private

        def send_no_requests_message
          reply(ESM::Embed.build(:success, description: "#{current_user.mention}, you do not have any pending requests"))
        end
      end
    end
  end
end
