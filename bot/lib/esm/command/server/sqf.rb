# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Sqf < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # Required: Needed by command
        argument :code_to_execute, display_name: :execute, required: true, preserve: true

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # Optional: Has default
        argument :target,
          required: false,
          checked_against: /#{ESM::Regex::TARGET.source}|server|all|everyone/i,
          default: "server"

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :execute_code
        command_type :admin

        limit_to :text

        # Argument 'target' will trigger this check, but not all values are 'target' values
        skip_action :nil_target_user

        ################################

        def on_execute
          check_for_owned_server!
          check_for_registered_target_user! if target_user.is_a?(ESM::User)

          execute_on =
            case arguments.target
            when "all", "everyone"
              "all"
            when ->(_type) { target_user }
              "player"
            else
              "server"
            end

          response = call_sqf_function(
            "ESMs_command_sqf",
            execute_on: execute_on,
            code: arguments.code_to_execute
          )

          data = response.data
          translation_name = "responses.#{execute_on}"
          translation_name += "_with_result" if !data.result.nil?

          embed = ESM::Embed.build(
            :success,
            description: t(
              translation_name,
              user: current_user.mention,
              target_uid: target_uid,
              result: data.result,
              server_id: target_server.server_id
            )
          )

          reply(embed)
        end

        module V1
          def on_execute
            check_for_owned_server!

            execute_on =
              if target_user
                check_for_registered_target_user! if target_user.is_a?(ESM::User)

                # Return their steam uid
                target_uid
              else
                "server"
              end

            deliver!(command_name: "exec", function_name: "exec", target: execute_on, code: minify_sqf(arguments.code_to_execute))
          end

          def on_response
            return if @response.message.blank?

            reply(response_message)
          end

          def minify_sqf(sqf)
            [
              [/\s*;\s*/, ";"], [/\s*:\s*/, ":"], [/\s*,\s*/, ","], [/\s*\[\s*/, "["],
              [/\s*\]\s*/, "]"], [/\s*\(\s*/, "("], [/\s*\)\s*/, ")"], [/\s*-\s*/, "-"],
              [/\s*\+\s*/, "+"], [/\s*\/\s*/, "/"], [/\s*\*\s*/, "*"], [/\s*%\s*/, "%"],
              [/\s*=\s*/, "="], [/\s*!\s*/, "!"], [/\s*>\s*/, ">"], [/\s*<\s*/, "<"],
              [/\s*>>\s*/, ">>"], [/\s*&&\s*/, "&&"], [/\s*\|\|\s*/, "||"], [/\s*\}\s*/, "}"],
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
                  "commands.sqf_v1.responses.server_success_with_return",
                  user: current_user.mention,
                  response: match[1],
                  server_id: target_server.server_id
                )
              )
            when /executed code on server/i
              ESM::Embed.build(
                :success,
                description: I18n.t(
                  "commands.sqf_v1.responses.server_success",
                  user: current_user.mention,
                  server_id: target_server.server_id
                )
              )
            when /executed code on target/i
              ESM::Embed.build(
                :success,
                description: I18n.t(
                  "commands.sqf_v1.responses.target_success",
                  user: current_user.mention,
                  server_id: target_server.server_id,
                  target_uid: target_user.steam_uid
                )
              )
            when /invalid target/i
              ESM::Embed.build(
                :error,
                description: I18n.t(
                  "commands.sqf_v1.responses.invalid_target",
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
end
