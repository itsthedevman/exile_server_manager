# frozen_string_literal: true

module ESM
  module Command
    module Test
      class Base < ESM::Command::Base
        ARGUMENT_COUNT = 8
        COMMAND_AS_STRING = "**`<community_id>`**\nThe community ID for the community that you want to run this command on. These are 3 to 4 letters long and can be found by sending me `~id` on that community's discord.\n\n**`<server_id>`**\nThe ID for the server that you want to run this command on. Server IDs are composed of a community ID and a name set by the server owner.\nFor example, `esm_malden`, `esm_tanoa`, and `esm_some_awesome_server`.\n\n**`<target>`**\nA user that you want to run this command on. This argument accepts any of the following:\nA Discord mention, e.g. `@Bryan`\nA Discord ID, e.g. `137709767954137088`\nor a Steam 64 ID (Steam UID), e.g. `76561198037177305`.\n\n**`<_integer>`**\none.\n\n**`<_preserve>`**\ntwo.\n\n**`<sa_yalpsid>`**\nthree.\n\n**`<?_default>`**\ndefault.\n**Note:** This argument is optional and it defaults to `not_default`. \n\n**`<?_multiline>`**\nwild.\n**Note:** This argument is optional. \n\n"

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
        argument :_integer, regex: /1/, description: "test_base._integer", type: :integer
        argument :_preserve, regex: /preserve/, description: "test_base._preserve", preserve: true
        argument :_display_as, regex: /display_as/, description: "test_base._display_as", display_as: "sa_yalpsid"

        # Leave these at the end
        argument :_default, regex: /default/, description: "test_base._default", default: "not_default"
        argument :_multiline, regex: /multi\s+line/, description: "test_base._multiline", default: nil, preserve: true, multiline: true

        def discord
          "discord"
        end

        def server
          raise ESM::Exception::CheckFailure, ESM::Embed.build(:error, description: "This failed a check") if @defines.FLAG_RAISE_ERROR

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
