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
          run_checks!

          execute_on = execution_target
          response = call_sqf_function!("ESMs_command_sqf", execute_on:, code: arguments.code_to_execute)

          data = response.data

          translation_name = "responses.#{execute_on}"
          translation_name += "_with_result" if !data.result.nil?

          embed = ESM::Embed.build(
            :success,
            description: t(
              translation_name,
              user: current_user.mention,
              target_uid: target_uid,
              result: cast_result(data.result, data.type),
              server_id: target_server.server_id
            )
          )

          reply(embed)
        end

        def on_website_execute
          run_checks!

          execute_on = execution_target
          response = call_sqf_function!("ESMs_command_sqf", execute_on:, code: arguments.code_to_execute)

          data = response.data
          reply(result: cast_result(data.result, data.type))
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

        private

        def run_checks!
          check_for_owned_server!
          check_for_registered_target_user! if target_user.is_a?(ESM::User)
        end

        def execution_target
          case arguments.target
          when "all", "everyone"
            "all"
          when ->(_type) { target_user }
            "player"
          else
            "server"
          end
        end

        def cast_result(result, type)
          case type.upcase
          when "BOOL", "SCALAR"
            # Arma stores all numbers (floats, integers) as SCALAR (Like Numeric).
            # Since it's like JSON's Number, we can use the parser to handle them for us.
            # Boolean is also handled, so why not
            result.parse_json
          # Opted to not convert hashmaps to hash because arma is arma and we want to keep the data structures the same
          # when "HASHMAP"
          #   ESM::Arma::HashMap.from(result).to_h
          else
            # HASHMAP, ARRAY, STRING, NaN, CODE, SCRIPT, OBJECT, GROUP, CONTROL, TEAM_MEMBER, DISPLAY, TASK, LOCATION,
            # SIDE, TEXT, CONFIG, NAMESPACE, DIARY_RECORD, NIL
            result # Don't convert, already a string
          end
        end
      end
    end
  end
end
