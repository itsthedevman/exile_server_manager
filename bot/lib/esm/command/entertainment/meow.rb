# frozen_string_literal: true

module ESM
  module Command
    module Entertainment
      class Meow < ESM::Command::Base
        type :player
        aliases :cat, :kitty, :feline

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
          reply(link)
        end

        def check_for_empty_link!
          return if link.present?

          remove_waiting_message
          check_failed!(:meow_not_found, user: current_user.mention)
        end

        def link
          @link ||= lambda do
            5.times do
              response = HTTParty.get(
                "https://api.thecatapi.com/v1/images/search?size=full&mime_types=jpg&format=json&order=RANDOM&page=0&limit=1",
                headers: { 'User-agent': "ESM 2.0" }
              )
              next sleep(1) if !response.ok?

              url = response.parsed_response.first["url"]
              next if url.blank?

              return url
            end

            nil
          end.call
        end

        def send_waiting_message
          @message = reply(I18n.t("commands.meow.waiting"))
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
