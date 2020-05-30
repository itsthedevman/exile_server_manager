# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module General
      class Changelog < ESM::Command::Base
        type :player

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        def discord
          document = YAML.safe_load(File.read(File.expand_path("./changelog/#{ESM::VERSION}.yml")))

          message = "**__Exile Server Manager v#{ESM::VERSION}__**\n"
          message += document["header"] if document["header"]

          document["changelog"].each do |system, system_changes|
            message += "\n\n**__Changes to the #{system}__**\n#{system_changes}"
          end

          # Return the message
          Discordrb.split_message(message).each(&method(:reply))
        end
      end
    end
  end
end
