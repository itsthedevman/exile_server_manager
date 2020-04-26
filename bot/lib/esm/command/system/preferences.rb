# frozen_string_literal: true

module ESM
  module Command
    module System
      class Preferences < ESM::Command::Base
        TYPES = %w[
          all
          custom
          base-raid
          flag-stolen
          flag-restored
          flag-steal-started
          protection-money-due
          protection-money-paid
          grind-started
          hack-started
          charge-plant-started
          marxet-item-sold
        ].freeze

        type :player
        aliases :notif
        limit_to :dm
        requires :registration

        # This command is not dependent on the server being connected
        skip_check :connected_server

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :server_id
        argument :state, regex: /allow|deny/, description: "commands.preferences.arguments.state"
        argument :type, regex: /#{TYPES.join("|")}/, description: "commands.preferences.arguments.type", default: "all"

        def discord
          # Creates an array of ["custom"] or ["base-raid", "flag-stolen", "flag-restored", etc...]
          types =
            if @arguments.type == "all"
              # Remove "all" from the list
              TYPES.dup[1..-1]
            else
              [@arguments.type]
            end

          # Converts the array of types to { custom: true }, or { "base-raid": false, "flag-stolen": false, "flag-restored": false, etc... }
          query = Hash[types.map { |type| [type.underscore, allowed?] }]

          # Either create or update the preference
          preference = ESM::UserNotificationPreference.where(user_id: current_user.esm_user.id, server_id: target_server.id).first_or_create
          preference.update(query)

          reply(ESM::Embed.build(:success, description: ":white_check_mark: Your preferences for `#{target_server.server_id}` have been updated"))
        end

        def allowed?
          @arguments.state == "allow"
        end
      end
    end
  end
end
