# frozen_string_literal: true

module ESM
  module Command
    module Entertainment
      class Birb < ESM::Command::Base
        type :player

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: false, default: 2.times

        def discord
          send_waiting_message
          check_for_empty_link!
          remove_waiting_message

          # Send the link
          reply(birb_link)
        end

        module ErrorMessage
          def self.birb_not_found(user:)
            ESM::Embed.build do |e|
              e.description = I18n.t("command_errors.birb_not_found", user: user)
              e.color = :red
            end
          end
        end

        def check_for_empty_link!
          return if birb_link.present?

          remove_waiting_message
          check_failed!(:birb_not_found, user: current_user.mention)
        end

        def birb_link
          @birb_link ||= lambda do
            10_000.times do
              response = HTTParty.get("http://www.reddit.com/r/birb/random.json", headers: { 'User-agent': "ESM 2.0" })
              next sleep(1) if !response.ok?

              url = response.parsed_response[0]["data"]["children"][0]["data"]["url"]
              next if url.blank?
              next if !url.match(/\.jpg$|\.png$|\.gif$|\.jpeg$/i)

              return url
            end
          end.call
        end

        def send_waiting_message
          @message = reply(I18n.t("commands.birb.waiting"))
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
