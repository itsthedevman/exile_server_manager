# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Sqf < ESM::Command::Base
        type :admin
        aliases :exec, :execute
        limit_to :text
        requires :registration
        skip_check :connected_server

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :target, description: "commands.sqf.arguments.execution_target", default: nil, display_as: :execution_target
        argument :code_to_execute, regex: /[\s\S]+/, description: "commands.sqf.arguments.code_to_execute", preserve: true, multiline: true

        def discord
          @checks.owned_server!

          execute_on =
            if target_user
              @checks.registered_target_user! if target_user.is_a?(Discordrb::User)

              # Return their steam uid
              target_uid
            else
              "server"
            end

          deliver!(command_name: "exec", function_name: "exec", target: execute_on, code: minify_sqf(@arguments.code_to_execute))
        end

        def server
          return if @response.message.blank?

          reply(response_message)
        end

        def minify_sqf(sqf)
          [
            [/\s*\;\s*/, ";"], [/\s*\:\s*/, ":"], [/\s*\,\s*/, ","], [/\s*\[\s*/, "["],
            [/\s*\]\s*/, "]"], [/\s*\(\s*/, "("], [/\s*\)\s*/, ")"], [/\s*\-\s*/, "-"],
            [/\s*\+\s*/, "+"], [/\s*\/\s*/, "/"], [/\s*\*\s*/, "*"], [/\s*\%\s*/, "%"],
            [/\s*\=\s*/, "="], [/\s*\!\s*/, "!"], [/\s*\>\s*/, ">"], [/\s*\<\s*/, "<"],
            [/\s*\>\>\s*/, ">>"], [/\s*\&\&\s*/, "&&"], [/\s*\|\|\s*/, "||"], [/\s*\}\s*/, "}"],
            [/\s*\{\s*/, "{"], [/\s+/, " "], [/\n+/, ""], [/\r+/, ""], [/\t+/, ""]
          ].each do |group|
            sqf = sqf.gsub(group.first, group.second)
          end

          sqf
        end

        # Unfortunately, the SQF sends back a formatted string.
        # Match the response from the server and then reply back to the user with a new message
        def response_message
          case @response.message
          when /executed on server successfully/i
            match = @response.message.match(/```(.*)```/)

            ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.sqf.responses.server_success_with_return",
                user: current_user.mention,
                response: match[1],
                server_id: target_server.server_id
              )
            )
          when /executed code on server/i
            ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.sqf.responses.server_success",
                user: current_user.mention,
                server_id: target_server.server_id
              )
            )
          when /executed code on target/i
            ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.sqf.responses.target_success",
                user: current_user.mention,
                server_id: target_server.server_id,
                target_uid: target_user.steam_uid
              )
            )
          when /invalid target/i
            ESM::Embed.build(
              :error,
              description: I18n.t(
                "commands.sqf.responses.invalid_target",
                user: current_user.mention,
                server_id: target_server.server_id,
                target_uid: target_user.steam_uid
              )
            )
          else
            @response.message
          end
        end
      end
    end
  end
end
