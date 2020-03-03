# frozen_string_literal: true

module ESM
  module Command
    module Test
      class Base < ESM::Command::Base
        COMMAND_FULL = "!base esm esm_malden 137709767954137088 1 PRESERVE display_as default multi\nline"
        COMMAND_MINIMAL = "!base esm esm_malden 137709767954137088 1 PRESERVE display_as"
        COMMAND_INVALID_COMMUNITY = "!base es esm_malden 137709767954137088 1 PRESERVE display_as"
        COMMAND_INVALID_SERVER = "!base esm esm_mal 137709767954137088 1 PRESERVE display_as"
        COMMAND_INVALID_USER = "!base esm esm_malden 000000000000000000 1 PRESERVE display_as"
        ARGUMENT_COUNT = 8
        USAGE_STRING = "~base <community_id> <server_id> <target> <_integer> <_preserve> <sa_yalpsid> <?_default> <?_multiline>"
        MISSING_ARGUMENT_USAGE = "~base esm esm_malden 137709767954137088 1 <_preserve> <sa_yalpsid> <?_default> <?_multiline>"
        COMMAND_AS_STRING = "**`<community_id>`:** The community ID for the community that you want to run this command on. These are 3 to 4 letters long and can be found by sending me `!id` on that community's discord\n**`<server_id>`:** The ID for the server that you want to run this command on. Server IDs are composed of a community ID and a name set by the server owner.\nFor example, `esm_malden`, `esm_tanoa`, and `esm_some_awesome_server`\n**`<target>`:** A user that you want to run this command on. This argument accepts any of the following:\nA Discord mention, e.g. `@Bryan`\nA Discord ID, e.g. `137709767954137088`\nor a Steam 64 ID (Steam UID), e.g. `76561198037177305`\n**`<_integer>`:** one\n**`<_preserve>`:** two\n**`<sa_yalpsid>`:** three\n**`<?_default>`:** Optional, defaults to `not_default`. default\n**`<?_multiline>`:** Optional. wild\n"

        type :player
        aliases :base1, :base2

        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :community_id
        argument :server_id
        argument :target
        argument :_integer, regex: /1/, description: "one", type: :integer
        argument :_preserve, regex: /preserve/, description: "two", preserve: true
        argument :_display_as, regex: /display_as/, description: "three", display_as: "sa_yalpsid"

        # Leave these at the end
        argument :_default, regex: /default/, description: "default", default: "not_default"
        argument :_multiline, regex: /multi\s+line/, description: "wild", default: nil, preserve: true, multiline: true

        def discord
          "discord"
        end

        def server
          raise ESM::Exception::CheckFailure, "This failed a check" if @defines.FLAG_RAISE_ERROR

          "server"
        end

        module ErrorMessage
          def self.some_reason
            "I crashed! HALP!"
          end
        end
      end
    end
  end
end
