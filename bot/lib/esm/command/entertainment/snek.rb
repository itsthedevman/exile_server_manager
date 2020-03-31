# frozen_string_literal: true

module ESM
  module Command
    module Entertainment
      class Snek < ESM::Command::Base
        type :player
        aliases :snake, :nope_rope, :danger_noodle

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: false, default: 5.seconds

        def discord
          send_waiting_message
          check_for_empty_link!
          remove_waiting_message

          # Send the link
          link
        end

        module ErrorMessage
          def self.snek_not_found(user:)
            ESM::Embed.build do |e|
              e.description = I18n.t("command_errors.snek_not_found", user: user)
              e.color = :red
            end
          end
        end

        def check_for_empty_link!
          return if link.present?

          remove_waiting_message
          raise ESM::Exception::CheckFailure, error_message(:snek_not_found, user: current_user.mention)
        end

        def link
          @link ||= lambda do
            10_000.times do
              response = HTTParty.get("http://fur.im/snek/", headers: { 'User-agent': "ESM 2.0" })
              next sleep(1) if !response.ok?

              # They send stringed JSON as the response
              # "{\"file\":\"http:\\/\\/fur.im\\/snek\\/i\\/863.png\"}"
              url = response.parsed_response.to_h[:file]
              next if url.blank?

              return url
            end
          end.call
        end

        def send_waiting_message
          @message = reply(I18n.t("commands.snek.waiting"))
        end

        # Remove the "Waiting..." message
        def remove_waiting_message
          return if ESM.env.test?

          @message.delete
        end
      end
    end
  end
end
