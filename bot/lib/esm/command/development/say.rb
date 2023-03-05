# frozen_string_literal: true

module ESM
  module Command
    module Development
      class Say < ESM::Command::Base
        set_type :development
        requires :dev

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :text, regex: /.+/, preserve: true, description: "Text to make the bot say"

        def on_execute
          @event.message.delete if !ESM.env.test?
          reply(@arguments.text)
        end
      end
    end
  end
end
