# frozen_string_literal: true

module ESM
  module Command
    module Entertainment
      class Doggo < ESM::Command::Base
        type :player

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
          def self.doggo_not_found(user:)
            ESM::Embed.build do |e|
              e.description = I18n.t("command_errors.doggo_not_found", user: user)
              e.color = :red
            end
          end
        end

        def check_for_empty_link!
          return if link.present?

          remove_waiting_message
          raise ESM::Exception::CheckFailure, error_message(:doggo_not_found, user: current_user.mention)
        end

        def link
          @link ||= lambda do
            10_000.times do
              response = HTTParty.get("https://dog.ceo/api/breeds/image/random", headers: { 'User-agent': "ESM 2.0" })
              next sleep(1) if !response.ok?

              url = response.parsed_response["message"]
              next if url.blank?
              next if !url.match(/\.jpg$|\.png$|\.gif$|\.jpeg$/i)

              return url
            end
          end.call
        end

        def send_waiting_message
          @message = reply(I18n.t("commands.doggo.waiting"))
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
