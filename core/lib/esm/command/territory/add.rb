# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Add < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:target]
        argument :target, display_name: :whom

        # See Argument::TEMPLATES[:territory_id]
        argument :territory_id, display_name: :to

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_type :player
        command_namespace :territory, command_name: :add_player

        #################################

        def on_execute
          # A self-add or a territory admin: arma handles the add directly, no consent request needed.
          return on_request_accepted if instant_add?

          request_add!

          reply(ESM::Embed.build(:success, description: I18n.t("commands.request.sent")))
        end

        def on_website_execute
          # Self-adds and territory admins skip the consent request and arma processes the add straight away.
          # The row records which path ran so the page reads "Added" rather than "Request sent".
          if instant_add?
            embeds = add_to_territory!

            notify_requestee(embeds)
            reply(outcome: :added)

            return
          end

          request_add!

          reply(outcome: :requested)
        end

        def on_request_accepted
          embeds = add_to_territory!

          # Send to the requestee first since they can be the requestor
          notify_requestee(embeds)

          # And if they are the same person, don't send them the second message
          return if same_user?

          reply(embeds[:requestor])
        end

        module V1
          def on_request_accepted
            # Request the arma server to add the user
            deliver!(
              function_name: "addPlayerToTerritory",
              territory_id: arguments.territory_id,
              target_uid: target_user.steam_uid,
              uid: current_user.steam_uid
            )
          end

          def on_response
            # Send the success message to the requestee (which can be the requestor)
            embed = ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.add.requestee_success",
                user: target_user.mention,
                territory_id: arguments.territory_id
              )
            )

            ESM.discord_bot.deliver(embed, to: target_user)

            # Don't send essentially the same message twice
            return if same_user?

            # Send a message to the requestor (if they aren't the requestee as well)
            embed = ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.add.requestor_success",
                current_user: current_user.mention,
                target_user: target_user.distinct,
                territory_id: arguments.territory_id,
                server_id: target_server.server_id
              )
            )

            reply(embed)
          end
        end

        private

        # Whether the add bypasses the consent request. Arma still enforces the actual territory rights.
        def instant_add?
          same_user? || target_community.territory_admin_users.include?(current_user)
        end

        # Creates the pending request the target must accept, notifying them via the request message.
        def request_add!
          # Checks for a registered target user. This also keeps people from adding via steam_uid only.
          check_for_registered_target_user!
          check_for_pending_request!

          add_request(
            to: target_user,
            description: I18n.t(
              "commands.add.request_description",
              current_user: current_user.distinct,
              target_user: target_user.mention,
              territory_id: arguments.territory_id,
              server_id: target_server.server_id
            )
          )
        end

        # Runs the arma add and returns the requestee/requestor embeds parsed from the response.
        def add_to_territory!
          response = call_sqf_function!("ESMs_command_add", territory_id: arguments.territory_id)

          {
            requestee: embed_from_hash!(response.data.requestee),
            requestor: embed_from_hash!(response.data.requestor)
          }
        end

        # The target's "you've been added" notification, delivered over Discord (they can be the requestor).
        def notify_requestee(embeds)
          ESM.discord_bot.deliver(embeds[:requestee], to: target_user)
        end
      end
    end
  end
end
