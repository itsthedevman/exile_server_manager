# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Broadcast < ApplicationCommand
        # Discord truncates an embed description at 2048 rather than refusing it, so a message is capped below that here
        # and rejected outright - a broadcast that silently loses its last paragraph is worse than one that won't send.
        MESSAGE_LENGTH_MAX = 2000

        #################################
        #
        # Arguments (required first, then order matters)
        #

        # Required: All variants require a message
        argument :message, required: true, preserve_case: true

        # Optional: Omitting defaults to "preview"
        argument(
          :broadcast_to,
          display_name: :to,
          checked_against: ESM::Regex::BROADCAST,
          modifier: lambda do |content|
            return if content.blank?
            return content if %w[all preview].include?(content)

            # If we start with a community ID, just accept the match
            return content if content.match("^#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

            # Add the community ID to the front of the match
            "#{current_community.community_id}_#{content}"
          end
        )

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin
        command_type :admin

        limit_to :text

        #################################

        def on_execute
          check_for_message_length!

          # Send just the preview
          return reply(broadcast_embed) if arguments.broadcast_to == "preview" || arguments.broadcast_to.blank?

          # Preload the servers
          load_servers

          # Send a preview of the embed
          reply(broadcast_embed(server_ids: @server_id_sentence))
          reply("`---------------------------------`")

          embed =
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.broadcast.confirmation_embed.title")
              e.description = I18n.t("commands.broadcast.confirmation_embed.description", server_ids: @server_id_sentence)

              e.add_field(name: I18n.t("commands.broadcast.confirmation_embed.field_name"), value: I18n.t("commands.broadcast.confirmation_embed.field_value"))
            end

          # Send the confirmation request
          reply(embed)

          response = ESM.discord_bot.await_response(current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          if response.nil? || response.downcase == I18n.t("no").downcase
            return reply(I18n.t("commands.broadcast.cancellation_reply"))
          end

          # Get all of the users to broadcast to
          users = Audience.for(@servers)
          users.each { |user| ESM.discord_bot.deliver(broadcast_embed(server_ids: @server_id_sentence), to: user.discord_id) }

          # Send the success message back
          reply(
            ESM::Embed.build(
              :success,
              description: I18n.t("commands.broadcast.success_message", user: current_user.mention)
            )
          )
        end

        # The web surface has already shown the admin the rendered embed and made them confirm it, so this drops both
        # the preview and the yes/no await that carry that job on Discord. What is left is the send.
        def on_website_execute
          check_for_message_length!
          load_servers

          recipients = Audience.for(@servers)
          embed = broadcast_embed(server_ids: @server_id_sentence)

          recipients.each { |user| ESM.discord_bot.deliver(embed, to: user.discord_id) }

          reply(recipients: recipients.size)
        end

        private

        def broadcast_embed(server_ids: nil)
          # For the preview
          if server_ids.blank?
            server = current_community.servers.first
            server_ids = server&.server_id || "<server_id_here>"
          end

          ESM::Embed.build do |e|
            e.title = I18n.t("commands.broadcast.broadcast_embed.title", community_name: current_community.community_name, server_ids: server_ids)
            e.description = arguments.message
            e.color = :orange
            e.footer = I18n.t("commands.broadcast.broadcast_embed.footer")
          end
        end

        def load_servers
          @servers =
            if arguments.broadcast_to == "all"
              current_community.servers
            else
              # Find the server, but check existence and if the server belongs to this community
              server = ESM::Server.find_by_server_id(arguments.broadcast_to)

              raise_invalid_server_id! if server.nil?
              raise_no_server_access! if server.community_id != current_community.id

              [server]
            end

          # For the broadcast message
          @server_id_sentence = @servers.map { |server| "`#{server.server_id}`" }.to_sentence
        end

        def check_for_message_length!
          raise_error!(:message_length, user: current_user) if arguments.message.size > MESSAGE_LENGTH_MAX
        end

        def raise_no_server_access!
          raise_error!(:no_server_access, user: current_user, community_id: current_community.community_id)
        end

        def raise_invalid_server_id!
          raise_error!(
            :invalid_server_id,
            path_prefix: "command_errors",
            user: current_user,
            provided_server_id: arguments.broadcast_to
          )
        end
      end
    end
  end
end
